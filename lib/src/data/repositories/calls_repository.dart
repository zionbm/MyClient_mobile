import '../../core/network/api_transport.dart';

class CallsRepository {
  const CallsRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> list({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) => _transport.getJson(
    '/businesses/$businessId/calls',
    queryParameters: _page(limit, cursor),
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );
}

Map<String, String> _page(int? limit, String? cursor) => {
  if (limit != null) 'limit': '$limit',
  if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
};
