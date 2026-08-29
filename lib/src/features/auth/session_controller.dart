import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../api/api_client.dart';
import '../../models/session.dart';
import '../../services/push_notification_service.dart';

enum SessionStatus { signedOut, loading, needsBusiness, signedIn }

class SessionController extends ChangeNotifier {
  SessionController({
    required ApiClient apiClient,
    PushNotificationService? pushNotifications,
  }) : _apiClient = apiClient,
       _pushNotifications = pushNotifications;

  final ApiClient _apiClient;
  final PushNotificationService? _pushNotifications;

  ApiClient get apiClient => _apiClient;
  bool get isMockAuth => _apiClient.isMockAuth;

  SessionStatus _status = SessionStatus.signedOut;
  AppSession? _session;
  String? _errorMessage;
  int _dataVersion = 0;

  SessionStatus get status => _status;
  AppSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SessionStatus.loading;
  int get dataVersion => _dataVersion;

  Future<void> restorePersistedSession() async {
    if (isMockAuth || _status != SessionStatus.signedOut) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    await firebaseSignIn();
  }

  void markDataChanged() {
    _dataVersion += 1;
    notifyListeners();
  }

  Future<void> devSignIn({
    required String firebaseUid,
    String? phoneNumber,
  }) async {
    final normalizedPhone = phoneNumber?.trim();
    await _run(() async {
      final trimmedUid = firebaseUid.trim();
      final mockPhoneNumber = normalizedPhone?.isEmpty ?? true
          ? null
          : normalizedPhone;
      try {
        final json = await _apiClient.auth.getMe(
          firebaseUid: trimmedUid,
          mockPhoneNumber: mockPhoneNumber,
        );
        _setSession(
          AppSession.fromAuthMe(
            firebaseUid: trimmedUid,
            mockPhoneNumber: mockPhoneNumber,
            json: json,
          ),
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        _setSession(
          AppSession(
            firebaseUid: trimmedUid,
            mockPhoneNumber: mockPhoneNumber,
            onboardingState: 'NEEDS_CHOICE',
          ),
        );
      }
    });
  }

  Future<void> firebaseSignIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = 'נדרשת התחברות מחדש';
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }

    await _run(() async {
      try {
        final json = await _apiClient.auth.getMe(firebaseUid: user.uid);
        _setSession(
          AppSession.fromAuthMe(
            firebaseUid: user.uid,
            mockPhoneNumber: null,
            json: json,
          ),
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        _setSession(
          AppSession(firebaseUid: user.uid, onboardingState: 'NEEDS_CHOICE'),
        );
      }
    });
  }

  Future<void> registerBusiness({
    required String businessName,
    String? displayName,
  }) async {
    final current = _session;
    if (current == null) return;

    await _run(() async {
      await _apiClient.auth.registerBusiness(
        firebaseUid: current.firebaseUid,
        mockPhoneNumber: current.mockPhoneNumber,
        businessName: businessName,
        displayName: displayName,
      );
      final json = await _apiClient.auth.getMe(
        firebaseUid: current.firebaseUid,
        mockPhoneNumber: current.mockPhoneNumber,
      );
      _setSession(
        AppSession.fromAuthMe(
          firebaseUid: current.firebaseUid,
          mockPhoneNumber: current.mockPhoneNumber,
          json: json,
        ),
      );
    });
  }

  Future<void> refreshSession() async {
    final current = _session;
    if (current == null) return;
    final json = await _apiClient.auth.getMe(
      firebaseUid: current.firebaseUid,
      mockPhoneNumber: current.mockPhoneNumber,
    );
    _setSession(
      AppSession.fromAuthMe(
        firebaseUid: current.firebaseUid,
        mockPhoneNumber: current.mockPhoneNumber,
        json: json,
      ),
    );
  }

  void signOut() {
    if (!isMockAuth) {
      FirebaseAuth.instance.signOut();
    }
    _session = null;
    _errorMessage = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_pushNotifications?.dispose());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    _errorMessage = null;
    _status = SessionStatus.loading;
    notifyListeners();

    try {
      await action();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _status = _session == null
          ? SessionStatus.signedOut
          : _statusFor(_session!);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'אירעה שגיאה לא צפויה';
      _status = _session == null
          ? SessionStatus.signedOut
          : _statusFor(_session!);
      notifyListeners();
    }
  }

  void _setSession(AppSession session) {
    _session = session;
    _status = _statusFor(session);
    notifyListeners();
    if (_status == SessionStatus.signedIn) {
      unawaited(_pushNotifications?.configureForSession(session));
    }
  }

  SessionStatus _statusFor(AppSession session) {
    return session.hasBusiness
        ? SessionStatus.signedIn
        : SessionStatus.needsBusiness;
  }
}
