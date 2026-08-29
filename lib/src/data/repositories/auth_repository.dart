import '../../core/network/api_transport.dart';

class AuthRepository {
  const AuthRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> getMe({
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/auth/me',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> registerBusiness({
    required String firebaseUid,
    String? mockPhoneNumber,
    required String businessName,
    String? displayName,
  }) => _transport.sendJson(
    'POST',
    '/auth/register-business',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {
      'firebaseUid': firebaseUid,
      if (mockPhoneNumber != null && mockPhoneNumber.trim().isNotEmpty)
        'phoneNumber': mockPhoneNumber.trim(),
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'businessName': businessName.trim(),
    },
  );
}
