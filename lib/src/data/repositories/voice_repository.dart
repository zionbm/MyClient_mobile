import '../../core/network/api_transport.dart';

class VoiceRepository {
  const VoiceRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) => _transport.getJson(
    '/businesses/$businessId/voice-commands',
    queryParameters: {
      if (limit != null) 'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    },
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
  Future<Map<String, Object?>> createRealtimeSession({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/voice-commands/realtime-session',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
  Future<Map<String, Object?>> submitTranscript({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String transcript,
    required String idempotencyKey,
    String languageCode = 'he-IL',
  }) => _transport.sendTranscript(
    '/businesses/$businessId/voice-commands/transcript',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    headers: {
      'x-idempotency-key': idempotencyKey,
      'x-language-code': languageCode,
    },
    body: {
      'transcript': transcript,
      'languageCode': languageCode,
      'sttProvider': 'openai-realtime',
    },
  );
  Future<Map<String, Object?>> uploadAudio({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required List<int> bytes,
    required String idempotencyKey,
    String filename = 'owner-command.m4a',
    String languageCode = 'he-IL',
  }) => _transport.sendBytes(
    '/businesses/$businessId/voice-commands/audio',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    bytes: bytes,
    contentType: 'audio/mp4',
    headers: {
      'x-idempotency-key': idempotencyKey,
      'x-language-code': languageCode,
      'x-audio-filename': filename,
    },
  );
}
