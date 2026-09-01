import '../../core/network/api_transport.dart';
import '../../models/page.dart';
import '../../models/v2_activity.dart';

class V2ActivityRepository {
  const V2ActivityRepository(this._transport);
  final ApiTransport _transport;

  Future<Page<V2Activity>> list({
    required V2ActivityKind kind,
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? cursor,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/${kind.apiPath}s',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {'limit': '50', 'cursor': ?cursor},
    );
    return Page(
      items: (json['${kind.apiPath}s'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map((item) => V2Activity.fromJson(item, kind))
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<List<V2Activity>> schedule({
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
          (item) => V2Activity.fromJson(
            item,
            item['kind'] == 'visit' ? V2ActivityKind.visit : V2ActivityKind.job,
          ),
        )
        .toList(growable: false);
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

  Future<V2Activity> create({
    required V2ActivityKind kind,
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

  Future<V2Activity> get({
    required V2ActivityKind kind,
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
    return V2Activity.fromJson(
      json[kind.apiPath] as Map<String, Object?>,
      kind,
    );
  }

  Future<V2Activity> update({
    required V2ActivityKind kind,
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
    required V2ActivityKind kind,
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

  Future<V2Activity> lifecycle({
    required V2ActivityKind kind,
    required String businessId,
    required String entityId,
    required String action,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
    Map<String, Object?> body = const {},
  }) => _write(
    'POST',
    '/v2/businesses/$businessId/${kind.apiPath}s/$entityId/$action',
    kind,
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<V2Activity> _write(
    String method,
    String path,
    V2ActivityKind kind,
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
    return V2Activity.fromJson(
      json[kind.apiPath] as Map<String, Object?>,
      kind,
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
