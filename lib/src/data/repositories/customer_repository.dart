import '../../core/network/api_transport.dart';
import '../../models/customer.dart';
import '../../models/page.dart';

class CustomerRepository {
  const CustomerRepository(this._transport);

  final ApiTransport _transport;

  Future<Page<Customer>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) async {
    final json = await _transport.getJson(
      '/businesses/$businessId/customers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      queryParameters: {
        if (limit != null) 'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final items =
        (json['customers'] as List?)
            ?.whereType<Map<String, Object?>>()
            .map(Customer.fromJson)
            .toList(growable: false) ??
        const <Customer>[];
    return Page(items: items, pageInfo: PageInfo.fromJson(json['pageInfo']));
  }

  Future<Customer> create({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => _customerFromResponse(
    _transport.sendJson(
      'POST',
      '/businesses/$businessId/customers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    ),
  );

  Future<Customer> update({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => _customerFromResponse(
    _transport.sendJson(
      'PATCH',
      '/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    ),
  );

  Future<Customer> _customerFromResponse(
    Future<Map<String, Object?>> response,
  ) async {
    final json = await response;
    final customer = json['customer'];
    if (customer is! Map<String, Object?>) {
      throw const FormatException('Missing customer in API response');
    }
    return Customer.fromJson(customer);
  }
}
