import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required AppConfig config}) : _config = config;

  final AppConfig _config;
  final HttpClient _httpClient = HttpClient();

  void close() => _httpClient.close(force: true);

  Future<Map<String, Object?>> getAuthMe({
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return getJson(
      '/auth/me',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> registerBusiness({
    required String firebaseUid,
    String? mockPhoneNumber,
    required String businessName,
    String? displayName,
  }) {
    return postJson(
      '/auth/register-business',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: {
        'firebaseUid': firebaseUid,
        if (mockPhoneNumber != null && mockPhoneNumber.trim().isNotEmpty)
          'phoneNumber': mockPhoneNumber.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'businessName': businessName.trim(),
      },
    );
  }

  Future<Map<String, Object?>> getHome({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    DateTime? date,
    String? query,
    String filter = 'all',
  }) {
    final params = <String, String>{};
    if (date != null) {
      params['date'] = date.toIso8601String().split('T').first;
    }
    if (query != null && query.trim().isNotEmpty) {
      params['search'] = query.trim();
    }
    params['filter'] = filter;
    return getJson(
      '/businesses/$businessId/home',
      queryParameters: params,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final request = await _open(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    return _sendJson(request);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final request = await _open(
      method: 'POST',
      path: path,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return _sendJson(request);
  }

  Future<HttpClientRequest> _open({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    final baseUri = Uri.parse(_config.coreBaseUrl);
    final uri = baseUri.replace(
      path: _joinPath(baseUri.path, path),
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );

    return _httpClient.openUrl(method, uri).then((request) {
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer mock:$firebaseUid',
      );
      if (mockPhoneNumber != null && mockPhoneNumber.trim().isNotEmpty) {
        request.headers.set('x-mock-phone-number', mockPhoneNumber.trim());
      }
      return request;
    });
  }

  Future<Map<String, Object?>> _sendJson(HttpClientRequest request) async {
    late final HttpClientResponse response;
    try {
      response = await request.close().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw ApiException('השרת לא הגיב בזמן');
    } on SocketException {
      throw ApiException('לא ניתן להתחבר לשרת המקומי');
    }

    final text = await response.transform(utf8.decoder).join();
    final decoded = text.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(text);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractErrorMessage(decoded) ?? 'בקשת API נכשלה';
      throw ApiException(
        message,
        statusCode: response.statusCode,
        details: decoded,
      );
    }

    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    throw ApiException('השרת החזיר תשובה לא צפויה', details: decoded);
  }

  String _joinPath(String basePath, String path) {
    final cleanBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  String? _extractErrorMessage(Object? decoded) {
    if (decoded is Map<String, Object?>) {
      final error = decoded['error'];
      if (error is Map<String, Object?>) {
        final message = error['message'];
        if (message is String) return message;
      }
      final message = decoded['message'];
      if (message is String) return message;
    }
    return null;
  }
}
