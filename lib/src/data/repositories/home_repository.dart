import '../../core/network/api_transport.dart';

class HomeRepository {
  const HomeRepository(this._transport);

  final ApiTransport _transport;

  Future<Map<String, Object?>> get({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    DateTime? date,
    String? query,
    String filter = 'all',
  }) {
    return _transport.getJson(
      '/businesses/$businessId/home',
      queryParameters: {
        if (date != null) 'date': date.toIso8601String().split('T').first,
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
        'filter': filter,
      },
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }
}
