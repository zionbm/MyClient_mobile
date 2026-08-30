import '../../core/network/api_transport.dart';

class BusinessRepository {
  const BusinessRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> getSettings({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/businesses/$businessId/settings',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> updateSettings({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => _transport.sendJson(
    'PATCH',
    '/businesses/$businessId/settings',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: body,
  );
  Future<Map<String, Object?>> listPhoneNumbers({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/businesses/$businessId/phone-numbers',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> createPhoneNumber({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String phoneNumber,
    String? displayName,
    String status = 'ACTIVE',
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/phone-numbers',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {
      'plivoNumber': phoneNumber.trim(),
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'status': status,
    },
  );
  Future<Map<String, Object?>> updatePhoneNumber({
    required String businessId,
    required String phoneNumberId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? displayName,
    String? status,
  }) => _transport.sendJson(
    'PATCH',
    '/businesses/$businessId/phone-numbers/$phoneNumberId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {
      if (displayName != null)
        'displayName': displayName.trim().isEmpty ? null : displayName.trim(),
      'status': ?status,
    },
  );
  Future<Map<String, Object?>> listMembers({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/businesses/$businessId/members',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> createMember({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String phoneNumber,
    String? displayName,
    String memberType = 'EMPLOYEE',
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/members',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {
      'phoneNumber': phoneNumber.trim(),
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'memberType': memberType,
    },
  );
  Future<Map<String, Object?>> disableMember({
    required String businessId,
    required String memberId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/members/$memberId/disable',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
}
