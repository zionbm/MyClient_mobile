import '../../core/network/api_transport.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_amount.dart';

class V2AmountRepository {
  const V2AmountRepository(this._transport);
  final ApiTransport _transport;

  Future<V2Amount> get({
    required V2ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async => _amount(
    await _transport.getJson(
      _path(kind, businessId, entityId),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    ),
  );

  Future<V2Amount> put({
    required V2ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'PUT',
    _path(kind, businessId, entityId),
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<V2Amount> payment({
    required V2ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    required String idempotencyKey,
    required String mode,
    double? amount,
    String? mockPhoneNumber,
  }) => _write(
    'POST',
    '${_path(kind, businessId, entityId)}/payments',
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    {'mode': mode, 'amount': ?amount},
  );

  Future<Map<String, Object?>> paymentsReport({
    required String businessId,
    required String firebaseUid,
    required DateTime from,
    required DateTime to,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/reports/payments',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    queryParameters: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    },
  );

  Future<Map<String, Object?>> openBalances({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/reports/open-balances',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<V2Amount> _write(
    String method,
    String path,
    String firebaseUid,
    String? mockPhoneNumber,
    String idempotencyKey,
    Map<String, Object?> body,
  ) async => _amount(
    await _transport.sendJson(
      method,
      path,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    ),
  );

  V2Amount _amount(Map<String, Object?> json) =>
      V2Amount.fromJson(json['amount'] as Map<String, Object?>);

  static String _path(
    V2ActivityKind kind,
    String businessId,
    String entityId,
  ) => '/v2/businesses/$businessId/${kind.apiPath}s/$entityId/amount';
}
