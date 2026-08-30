import '../../core/network/api_transport.dart';

class NotificationsRepository {
  const NotificationsRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? status,
    int? limit,
    String? cursor,
  }) => _transport.getJson(
    '/businesses/$businessId/notifications',
    queryParameters: {
      if (limit != null) 'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'status': ?status,
    },
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> markRead({
    required String businessId,
    required String notificationId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _post(
    '/businesses/$businessId/notifications/$notificationId/read',
    businessId: businessId,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> markAllRead({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _post(
    '/businesses/$businessId/notifications/read-all',
    businessId: businessId,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> snooze({
    required String businessId,
    required String notificationId,
    required String preset,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/notifications/$notificationId/snooze',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {'preset': preset},
  );

  Future<Map<String, Object?>> registerDeviceToken({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String token,
    String? platform,
    String? appVersion,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/device-tokens',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {'token': token, 'platform': ?platform, 'appVersion': ?appVersion},
  );

  Future<Map<String, Object?>> _post(
    String path, {
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    path,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
}
