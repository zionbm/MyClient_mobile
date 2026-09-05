import '../../core/network/api_transport.dart';
import '../../models/activity.dart';
import '../../models/amount.dart';

class AmountRepository {
  const AmountRepository(this._transport);
  final ApiTransport _transport;

  Future<Amount> get({
    required ActivityKind kind,
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

  Future<Amount> put({
    required ActivityKind kind,
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

  Future<Amount> update({
    required ActivityKind kind,
    required String businessId,
    required String entityId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) => _write(
    'PATCH',
    _path(kind, businessId, entityId),
    firebaseUid,
    mockPhoneNumber,
    idempotencyKey,
    body,
  );

  Future<Amount> payment({
    required ActivityKind kind,
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

  Future<Amount> _write(
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

  Amount _amount(Map<String, Object?> json) =>
      Amount.fromJson(json['amount'] as Map<String, Object?>);

  static String _path(ActivityKind kind, String businessId, String entityId) =>
      '/v2/businesses/$businessId/${kind.apiPath}s/$entityId/amount';
}
