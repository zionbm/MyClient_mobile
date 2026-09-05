import '../../core/network/api_transport.dart';

class ActionBatchesRepository {
  const ActionBatchesRepository(this._transport);
  final ApiTransport _transport;

  Future<Map<String, Object?>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/action-batches',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> preview({
    required String businessId,
    required String actionBatchId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/action-batches/$actionBatchId/undo-preview',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );

  Future<Map<String, Object?>> undo({
    required String businessId,
    required String actionBatchId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/action-batches/$actionBatchId/undo',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    headers: {'x-idempotency-key': idempotencyKey},
    body: const {'confirmed': true},
  );

  Future<Map<String, Object?>> speech({
    required String businessId,
    required String actionBatchId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/action-batches/$actionBatchId/speech',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );

  Future<Map<String, Object?>> preferences({
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/users/me/preferences',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> updatePreferences({
    required String firebaseUid,
    required String mode,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'PATCH',
    '/v2/users/me/preferences',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {'assistantResponseMode': mode},
  );
}
