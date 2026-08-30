import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/session.dart';
import '../../services/push_notification_service.dart';

enum SessionStatus { signedOut, loading, needsBusiness, signedIn }

class SessionController extends ChangeNotifier {
  SessionController({
    required ApiClient apiClient,
    PushNotificationService? pushNotifications,
    required DataInvalidator dataInvalidator,
  }) : _apiClient = apiClient,
       _pushNotifications = pushNotifications,
       _dataInvalidator = dataInvalidator;

  final ApiClient _apiClient;
  final PushNotificationService? _pushNotifications;
  final DataInvalidator _dataInvalidator;

  ApiClient get apiClient => _apiClient;
  bool get isMockAuth => _apiClient.isMockAuth;

  SessionStatus _status = SessionStatus.signedOut;
  AppSession? _session;
  String? _errorMessage;
  int _operationGeneration = 0;
  bool _disposed = false;

  SessionStatus get status => _status;
  AppSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SessionStatus.loading;
  DataInvalidator get dataInvalidator => _dataInvalidator;

  Future<void> restorePersistedSession() async {
    if (isMockAuth || _status != SessionStatus.signedOut) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    await firebaseSignIn();
  }

  void markDataChanged([Set<DataScope> scopes = const {DataScope.crm}]) {
    _dataInvalidator.invalidate(scopes);
  }

  void markAiActionResolved() {
    markDataChanged({DataScope.crm, DataScope.ai});
  }

  void refreshPendingActions() {
    markDataChanged({DataScope.ai});
  }

  Future<void> devSignIn({
    required String firebaseUid,
    String? phoneNumber,
  }) async {
    final normalizedPhone = phoneNumber?.trim();
    await _run((generation) async {
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
          generation: generation,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        _setSession(
          AppSession(
            firebaseUid: trimmedUid,
            mockPhoneNumber: mockPhoneNumber,
            onboardingState: 'NEEDS_CHOICE',
          ),
          generation: generation,
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

    await _run((generation) async {
      try {
        final json = await _apiClient.auth.getMe(firebaseUid: user.uid);
        _setSession(
          AppSession.fromAuthMe(
            firebaseUid: user.uid,
            mockPhoneNumber: null,
            json: json,
          ),
          generation: generation,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        _setSession(
          AppSession(firebaseUid: user.uid, onboardingState: 'NEEDS_CHOICE'),
          generation: generation,
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

    await _run((generation) async {
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
        generation: generation,
      );
    });
  }

  Future<void> refreshSession() async {
    final current = _session;
    if (current == null) return;
    final generation = _operationGeneration;
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
      generation: generation,
    );
  }

  Future<void> signOut() async {
    _operationGeneration += 1;
    _session = null;
    _errorMessage = null;
    _status = SessionStatus.signedOut;
    _notify();
    await _pushNotifications?.clearSession();
    if (!isMockAuth) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration += 1;
    unawaited(_pushNotifications?.dispose());
    super.dispose();
  }

  Future<void> _run(Future<void> Function(int generation) action) async {
    final generation = ++_operationGeneration;
    _errorMessage = null;
    _status = SessionStatus.loading;
    _notify();

    try {
      await action(generation);
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;
      _errorMessage = error.message;
      _status = _session == null
          ? SessionStatus.signedOut
          : _statusFor(_session!);
      _notify();
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _errorMessage = 'אירעה שגיאה לא צפויה';
      _status = _session == null
          ? SessionStatus.signedOut
          : _statusFor(_session!);
      _notify();
    }
  }

  void _setSession(AppSession session, {required int generation}) {
    if (!_isCurrent(generation)) return;
    _session = session;
    _status = _statusFor(session);
    _notify();
    if (_status == SessionStatus.signedIn) {
      unawaited(_pushNotifications?.configureForSession(session));
    }
  }

  SessionStatus _statusFor(AppSession session) {
    return session.hasBusiness
        ? SessionStatus.signedIn
        : SessionStatus.needsBusiness;
  }

  bool _isCurrent(int generation) {
    return !_disposed && generation == _operationGeneration;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
