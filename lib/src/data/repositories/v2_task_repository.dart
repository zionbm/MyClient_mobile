import '../../core/network/api_transport.dart';
import '../../models/page.dart';
import '../../models/v2_task.dart';

class V2TaskRepository {
  const V2TaskRepository(this._transport);
  final ApiTransport _transport;

  Future<Page<V2Task>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int limit = 50,
    String? cursor,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/tasks',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {'limit': '$limit', 'cursor': ?cursor},
    );
    return Page(
      items: (json['tasks'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(V2Task.fromJson)
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<V2Task> create({
    required String businessId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/tasks',
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<V2Task> get({
    required String businessId,
    required String taskId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/tasks/$taskId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    return V2Task.fromJson(json['task'] as Map<String, Object?>);
  }

  Future<V2Task> update({
    required String businessId,
    required String taskId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'PATCH',
    '/v2/businesses/$businessId/tasks/$taskId',
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<V2Task> lifecycle({
    required String businessId,
    required String taskId,
    required String action,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/tasks/$taskId/$action',
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    const {},
  );

  Future<V2Task> _write(
    String method,
    String path,
    String firebaseUid,
    String? mockPhoneNumber,
    String idempotencyKey,
    Map<String, Object?> body,
  ) async {
    final json = await _transport.sendJson(
      method,
      path,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return V2Task.fromJson(json['task'] as Map<String, Object?>);
  }
}
