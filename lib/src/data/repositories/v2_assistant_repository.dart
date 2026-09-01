import '../../core/network/api_transport.dart';

class V2AssistantRepository {
  const V2AssistantRepository(this._transport);

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
      throw const FormatException('Missing V2 assistant session id');
    }
    return _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/assistant/sessions/$sessionId/commands',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: {'clientSessionId': clientSessionId, 'transcript': transcript},
    );
  }
}
