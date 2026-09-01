import '../../core/network/api_transport.dart';

class VoiceRepository {
  const VoiceRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> createRealtimeSession({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/assistant/realtime-session',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
}
