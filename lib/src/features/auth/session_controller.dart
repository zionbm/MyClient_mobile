import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../models/session.dart';

enum SessionStatus { signedOut, loading, needsBusiness, signedIn }

class SessionController extends ChangeNotifier {
  SessionController({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  SessionStatus _status = SessionStatus.signedOut;
  AppSession? _session;
  String? _errorMessage;
  int _dataVersion = 0;

  SessionStatus get status => _status;
  AppSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SessionStatus.loading;
  int get dataVersion => _dataVersion;

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
      final json = await _apiClient.getAuthMe(
        firebaseUid: firebaseUid.trim(),
        mockPhoneNumber: normalizedPhone?.isEmpty ?? true
            ? null
            : normalizedPhone,
      );
      _setSession(
        AppSession.fromAuthMe(
          firebaseUid: firebaseUid.trim(),
          mockPhoneNumber: normalizedPhone?.isEmpty ?? true
              ? null
              : normalizedPhone,
          json: json,
        ),
      );
    });
  }

  Future<void> registerBusiness({
    required String businessName,
    String? displayName,
  }) async {
    final current = _session;
    if (current == null) return;

    await _run(() async {
      await _apiClient.registerBusiness(
        firebaseUid: current.firebaseUid,
        mockPhoneNumber: current.mockPhoneNumber,
        businessName: businessName,
        displayName: displayName,
      );
      final json = await _apiClient.getAuthMe(
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
    final json = await _apiClient.getAuthMe(
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
    _session = null;
    _errorMessage = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
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
  }

  SessionStatus _statusFor(AppSession session) {
    return session.hasBusiness
        ? SessionStatus.signedIn
        : SessionStatus.needsBusiness;
  }
}
