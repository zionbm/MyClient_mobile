import '../../core/network/api_transport.dart';

class AssistantRepository {
  const AssistantRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> submitTranscript({
    required String businessId,
    required String firebaseUid,
    required String clientSessionId,
    required String transcript,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    final sessionResponse = await _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/assistant/sessions',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': '$idempotencyKey:session'},
      body: {'clientSessionId': clientSessionId},
    );
    final session = sessionResponse['session'] as Map<String, Object?>?;
    final sessionId = session?['id'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw const FormatException('Missing  assistant session id');
    }
    return _transport.sendTranscript(
      '/v2/businesses/$businessId/assistant/sessions/$sessionId/commands',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: {'clientSessionId': clientSessionId, 'transcript': transcript},
    );
  }

  Future<Map<String, Object?>> listPending({
    required String businessId,
    required String firebaseUid,
    String status = 'PENDING',
    String? actionBatchId,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/assistant/pending-actions',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    queryParameters: {
      'status': status,
      'limit': '50',
      'actionBatchId': ?actionBatchId,
    },
  );

  Future<Map<String, Object?>> resolvePending({
    required String businessId,
    required String pendingActionId,
    required String firebaseUid,
    required String idempotencyKey,
    String? selectedEntityId,
    Map<String, Object?>? payload,
    bool confirmed = false,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/assistant/pending-actions/$pendingActionId/resolve',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    headers: {'x-idempotency-key': idempotencyKey},
    body: {
      'selectedEntityId': ?selectedEntityId,
      if (payload != null && payload.isNotEmpty) 'payload': payload,
      if (confirmed) 'confirmed': true,
    },
  );

  Future<Map<String, Object?>> rejectPending({
    required String businessId,
    required String pendingActionId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/assistant/pending-actions/$pendingActionId/reject',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    headers: {'x-idempotency-key': idempotencyKey},
    body: const {},
  );
}
