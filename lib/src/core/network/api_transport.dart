import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../observability/app_error_reporter.dart';
import 'api_exception.dart';

/// The only component allowed to create HTTP requests to Core.
///
/// Feature repositories own endpoint paths and payloads; this class owns URI
/// construction, authentication, timeouts and safe conversion of failures.
class ApiTransport {
  ApiTransport({required AppConfig config}) : _config = config;

  final AppConfig _config;
  final HttpClient _httpClient = HttpClient();

  bool get isMockAuth => _config.isMockAuth;

  void close() => _httpClient.close(force: true);

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _withRecovery((forceRefresh) async {
      final request = await _open(
        method: 'GET',
        path: path,
        queryParameters: queryParameters,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        forceRefresh: forceRefresh,
      );
      return _sendJson(request);
    }, retryTransient: true);
  }

  Future<Map<String, Object?>> sendJson(
    String method,
    String path, {
    required Map<String, Object?> body,
    required String firebaseUid,
    String? mockPhoneNumber,
    Map<String, String>? headers,
  }) async {
    return _withRecovery((forceRefresh) async {
      final request = await _open(
        method: method,
        path: path,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        forceRefresh: forceRefresh,
      );
      request.headers.contentType = ContentType.json;
      headers?.forEach(request.headers.set);
      request.write(jsonEncode(body));
      return _sendJson(request);
    });
  }

  Future<Map<String, Object?>> sendBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
    required Map<String, String> headers,
    required String firebaseUid,
    String? mockPhoneNumber,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    return _withRecovery((forceRefresh) async {
      final request = await _open(
        method: 'POST',
        path: path,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        forceRefresh: forceRefresh,
      );
      request.headers.contentType = ContentType.parse(contentType);
      headers.forEach(request.headers.set);
      request.add(bytes);
      return _sendJson(request, timeout: timeout);
    });
  }

  Future<Map<String, Object?>> sendTranscript(
    String path, {
    required Map<String, Object?> body,
    required Map<String, String> headers,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _withRecovery((forceRefresh) async {
      final request = await _open(
        method: 'POST',
        path: path,
        firebaseUid: firebaseUid,
        mockPhoneNumber: mockPhoneNumber,
        forceRefresh: forceRefresh,
      );
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      return _sendJson(request, timeout: const Duration(seconds: 120));
    });
  }

  Future<HttpClientRequest> _open({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    required String firebaseUid,
    String? mockPhoneNumber,
    bool forceRefresh = false,
  }) async {
    final baseUri = _config.coreBaseUri;
    final uri = baseUri.replace(
      path: _joinPath(baseUri.path, path),
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );
    final HttpClientRequest request;
    try {
      request = await _httpClient
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_open_timeout');
      throw const ApiException('השרת לא הגיב בזמן');
    } on SocketException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_open_socket');
      throw const ApiException('לא ניתן להתחבר לשרת');
    } on HandshakeException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_tls');
      throw const ApiException('לא ניתן ליצור חיבור מאובטח לשרת');
    } on HttpException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_open_http');
      throw const ApiException('לא ניתן להתחבר לשרת');
    }
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (isMockAuth) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer mock:$firebaseUid',
      );
      if (mockPhoneNumber != null && mockPhoneNumber.trim().isNotEmpty) {
        request.headers.set('x-mock-phone-number', mockPhoneNumber.trim());
      }
      return request;
    }

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(
      forceRefresh,
    );
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('נדרשת התחברות מחדש', statusCode: 401);
    }
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    return request;
  }

  Future<Map<String, Object?>> _sendJson(
    HttpClientRequest request, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = text.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(text);
      _log(request.method, response.statusCode);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _extractErrorMessage(decoded) ?? 'בקשת API נכשלה',
          statusCode: response.statusCode,
          details: decoded,
        );
      }
      if (decoded is Map<String, Object?>) return decoded;
      throw ApiException('השרת החזיר תשובה לא צפויה', details: decoded);
    } on TimeoutException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_timeout');
      throw const ApiException('השרת לא הגיב בזמן');
    } on SocketException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_socket');
      throw const ApiException('לא ניתן להתחבר לשרת');
    } on FormatException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'core_api_format');
      throw const ApiException('התקבלה תשובה לא תקינה מהשרת');
    }
  }

  Future<Map<String, Object?>> _withRecovery(
    Future<Map<String, Object?>> Function(bool forceRefresh) operation, {
    bool retryTransient = false,
  }) async {
    try {
      return await operation(false);
    } on ApiException catch (error) {
      if (!isMockAuth && error.statusCode == 401) return operation(true);
      if (retryTransient && error.statusCode == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return operation(false);
      }
      rethrow;
    }
  }

  void _log(String method, int statusCode) {
    if (kDebugMode) debugPrint('Core API $method → $statusCode');
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
      if (error is Map<String, Object?> && error['message'] is String) {
        return error['message'] as String;
      }
      if (decoded['message'] is String) return decoded['message'] as String;
    }
    return null;
  }
}
