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
    String? state,
    String? customerId,
    DateTime? dueBefore,
    bool? includeUndated,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/tasks',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        'limit': '$limit',
        'cursor': ?cursor,
        'state': ?state,
        'customerId': ?customerId,
        'dueBefore': ?dueBefore?.toUtc().toIso8601String(),
        'includeUndated': ?includeUndated?.toString(),
      },
    );
    return Page(
      items: (json['tasks'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(V2Task.fromJson)
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<List<V2Task>> listAll({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? state,
    String? customerId,
    DateTime? dueBefore,
    bool? includeUndated,
  }) async {
    final items = <V2Task>[];
    String? cursor;
    do {
      final page = await list(
        businessId: businessId,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        cursor: cursor,
        state: state,
        customerId: customerId,
        dueBefore: dueBefore,
        includeUndated: includeUndated,
      );
      items.addAll(page.items);
      cursor = page.pageInfo.hasMore ? page.pageInfo.nextCursor : null;
    } while (cursor != null);
    return items;
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
    required V2TaskAction action,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/tasks/$taskId/${action.apiValue}',
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    const {},
  );

  Future<void> delete({
    required String businessId,
    required String taskId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/tasks/$taskId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {},
    );
  }

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
