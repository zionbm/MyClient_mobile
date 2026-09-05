import '../../core/network/api_transport.dart';
import '../../models/page.dart';
import '../../models/customer.dart';

class CustomerRepository {
  const CustomerRepository(this._transport);
  final ApiTransport _transport;

  Future<Page<Customer>> list({
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
      queryParameters: {'limit': '$limit', 'cursor': ?cursor},
    );
    return Page(
      items: (json['customers'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(Customer.fromJson)
          .toList(growable: false),
      pageInfo: PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<Customer> get({
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

  Future<List<Map<String, Object?>>> timeline({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/v2/businesses/$businessId/customers/$customerId/timeline',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    return (json['items'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  Future<Customer> create({
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

  Future<Customer> update({
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

  Future<CustomerPhone> addPhone({
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
    return CustomerPhone.fromJson(json['phone'] as Map<String, Object?>);
  }

  Future<CustomerPhone> updatePhone({
    required String businessId,
    required String customerId,
    required String phoneId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'PATCH',
      '/v2/businesses/$businessId/customers/$customerId/phones/$phoneId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return CustomerPhone.fromJson(json['phone'] as Map<String, Object?>);
  }

  Future<void> deletePhone({
    required String businessId,
    required String customerId,
    required String phoneId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/customers/$customerId/phones/$phoneId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {},
    );
  }

  Future<ServiceAddress> addAddress({
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
    return ServiceAddress.fromJson(json['address'] as Map<String, Object?>);
  }

  Future<ServiceAddress> updateAddress({
    required String businessId,
    required String customerId,
    required String addressId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'PATCH',
      '/v2/businesses/$businessId/customers/$customerId/addresses/$addressId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return ServiceAddress.fromJson(json['address'] as Map<String, Object?>);
  }

  Future<Note> createNote({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'POST',
      '/v2/businesses/$businessId/customers/$customerId/notes',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return Note.fromJson(json['note'] as Map<String, Object?>);
  }

  Future<Note> updateNote({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    required String idempotencyKey,
    required Map<String, Object?> body,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.sendJson(
      'PATCH',
      '/v2/businesses/$businessId/customers/$customerId/notes/$noteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: body,
    );
    return Note.fromJson(json['note'] as Map<String, Object?>);
  }

  Future<void> deleteNote({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/customers/$customerId/notes/$noteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {},
    );
  }

  Future<void> deleteAddress({
    required String businessId,
    required String customerId,
    required String addressId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/customers/$customerId/addresses/$addressId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {},
    );
  }

  Future<void> delete({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/v2/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {'x-idempotency-key': idempotencyKey},
      body: const {'confirmed': true},
    );
  }

  Future<Map<String, Object?>> merge({
    required String businessId,
    required String sourceCustomerId,
    required String targetCustomerId,
    required String firebaseUid,
    required String idempotencyKey,
    String? mockPhoneNumber,
  }) => _transport.sendJson(
    'POST',
    '/v2/businesses/$businessId/customers/$sourceCustomerId/merge',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    headers: {'x-idempotency-key': idempotencyKey},
    body: {'confirmed': true, 'targetCustomerId': targetCustomerId},
  );

  Customer _customer(Map<String, Object?> json) =>
      Customer.fromJson(json['customer'] as Map<String, Object?>);
}
