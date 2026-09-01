import '../../core/network/api_transport.dart';
import '../../models/page.dart';
import '../../models/v2_customer.dart';

class V2CustomerRepository {
  const V2CustomerRepository(this._transport);
  final ApiTransport _transport;

  Future<Page<V2Customer>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int limit = 50,
    String? cursor,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/customers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        'limit': '$limit',
        'cursor': ?cursor,
      },
    );
    return Page(
      items: (json['customers'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(V2Customer.fromJson)
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<V2Customer> get({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async => _customer(
    await _transport.getJson(
      '/v2/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    ),
  );

  Future<V2Customer> create({
    required String businessId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async => _customer(
    await _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/customers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    ),
  );

  Future<V2Customer> update({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async => _customer(
    await _transport.sendJson(
      'PATCH',
      '/v2/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    ),
  );

  Future<V2CustomerPhone> addPhone({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/customers/$customerId/phones',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return V2CustomerPhone.fromJson(json['phone'] as Map<String, Object?>);
  }

  Future<V2ServiceAddress> addAddress({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/customers/$customerId/addresses',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return V2ServiceAddress.fromJson(json['address'] as Map<String, Object?>);
  }

  V2Customer _customer(Map<String, Object?> json) =>
      V2Customer.fromJson(json['customer'] as Map<String, Object?>);
}
