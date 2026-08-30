import '../../core/network/api_transport.dart';

class SearchRepository {
  const SearchRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> search({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String query,
    required String target,
    String status = 'all',
    int limit = 50,
    String? cursor,
  }) => _transport.getJson(
    '/businesses/$businessId/search',
    queryParameters: {
      'query': query,
      'target': target,
      'status': status,
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    },
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
}
