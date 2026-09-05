import '../../core/network/api_transport.dart';
import '../../models/page.dart';
import '../../models/activity.dart';
import '../../models/completed_item.dart';
import '../../models/task.dart';

class ActivityRepository {
  const ActivityRepository(this._transport);
  final ApiTransport _transport;

  Future<Page<Activity>> list({
    required ActivityKind kind,
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? cursor,
    String? status,
    String? customerId,
    bool? scheduled,
    bool? executed,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/${kind.apiPath}s',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        'limit': '50',
        'cursor': ?cursor,
        'status': ?status,
        'customerId': ?customerId,
        'scheduled': ?scheduled?.toString(),
        'executed': ?executed?.toString(),
      },
    );
    return Page(
      items: (json['${kind.apiPath}s'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map((item) => Activity.fromJson(item, kind))
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<List<Activity>> listAll({
    required ActivityKind kind,
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? status,
    String? customerId,
    bool? scheduled,
    bool? executed,
  }) async {
    final items = <Activity>[];
    String? cursor;
    do {
      final page = await list(
        kind: kind,
        businessId: businessId,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        cursor: cursor,
        status: status,
        customerId: customerId,
        scheduled: scheduled,
        executed: executed,
      );
      items.addAll(page.items);
      cursor = page.pageInfo.hasMore ? page.pageInfo.nextCursor : null;
    } while (cursor != null);
    return items;
  }

  Future<List<Activity>> schedule({
    required String businessId,
    required String firebaseUid,
    required DateTime from,
    required DateTime to,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/schedule',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return (json['items'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (item) => Activity.fromJson(
            item,
            item['kind'] == 'visit' ? ActivityKind.visit : ActivityKind.job,
          ),
        )
        .toList(growable: false);
  }

  Future<List<CompletedItem>> completed({
    required String businessId,
    required String firebaseUid,
    required DateTime from,
    required DateTime to,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/completed',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final tasks = (json['tasks'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(Task.fromJson)
        .where((task) => task.completedAt != null)
        .map(CompletedItem.task);
    final activities = (json['activities'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (item) => Activity.fromJson(
            item,
            item['kind'] == 'visit' ? ActivityKind.visit : ActivityKind.job,
          ),
        )
        .where((activity) => activity.executionCompletedAt != null)
        .map(CompletedItem.activity);
    return [...tasks, ...activities]
      ..sort((left, right) => right.completedAt.compareTo(left.completedAt));
  }

  Future<Map<String, Object?>> availability({
    required String businessId,
    required String firebaseUid,
    required DateTime date,
    required int durationMinutes,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/availability',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    queryParameters: {
      'date': _date(date),
      'durationMinutes': '$durationMinutes',
    },
  );

  Future<Activity> create({
    required ActivityKind kind,
    required String businessId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/${kind.apiPath}s',
    kind,
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<Activity> get({
    required ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/${kind.apiPath}s/$entityId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    return Activity.fromJson(json[kind.apiPath] as Map<String, Object?>, kind);
  }

  Future<Activity> update({
    required ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'PATCH',
    '/v2/businesses/$businessId/${kind.apiPath}s/$entityId',
    kind,
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<void> delete({
    required ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/${kind.apiPath}s/$entityId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {},
    );
  }

  Future<Activity> lifecycle({
    required ActivityKind kind,
    required String businessId,
    required String entityId,
    required ActivityAction action,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
    Map<String, Object?> body = const {},
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/${kind.apiPath}s/$entityId/${action.apiValue}',
    kind,
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<Activity> _write(
    String method,
    String path,
    ActivityKind kind,
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
    return Activity.fromJson(json[kind.apiPath] as Map<String, Object?>, kind);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
