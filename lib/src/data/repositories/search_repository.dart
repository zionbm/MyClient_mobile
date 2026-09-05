import '../../core/network/api_transport.dart';

class SearchRepository {
  const SearchRepository(this._transport);
  final ApiTransport _transport;

  Future<Map<String, Object?>> search({
    required String businessId,
    required String firebaseUid,
    required String query,
    String target = 'all',
    String status = 'all',
    String? mockPhoneNumber,
    String? cursor,
  }) => _transport.getJson(
    '/v2/businesses/$businessId/search',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    queryParameters: {
      'query': query,
      'target': target,
      'status': status,
      'limit': '50',
      'cursor': ?cursor,
    },
  );
}
