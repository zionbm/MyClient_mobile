import '../../core/network/api_transport.dart';

class NotesRepository {
  const NotesRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> create({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String text,
  }) => _transport.sendJson(
    'POST',
    '/businesses/$businessId/customers/$customerId/notes',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: {'text': text.trim()},
  );

  Future<Map<String, Object?>> update({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => _transport.sendJson(
    'PATCH',
    '/businesses/$businessId/customers/$customerId/notes/$noteId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: body,
  );

  Future<Map<String, Object?>> delete({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'DELETE',
    '/businesses/$businessId/customers/$customerId/notes/$noteId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );
}
