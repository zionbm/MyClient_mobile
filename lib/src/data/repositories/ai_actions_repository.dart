import '../../core/network/api_transport.dart';

class AiActionsRepository {
  const AiActionsRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? status,
    int? limit,
    String? cursor,
  }) => _transport.getJson(
    '/businesses/$businessId/ai-pending-actions',
    queryParameters: {
      if (limit != null) 'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'status': ?status,
    },
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> update({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => _transport.sendJson(
    'PATCH',
    '/businesses/$businessId/ai-pending-actions/$aiPendingActionId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: body,
  );
  Future<Map<String, Object?>> approve({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
    Map<String, Object?> payload = const {},
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/ai-pending-actions/$aiPendingActionId/approve',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: payload.isEmpty ? const {} : {'payload': payload},
  );
  Future<Map<String, Object?>> reject({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/ai-pending-actions/$aiPendingActionId/reject',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
}
