import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ApiFailureKind {
  networkOrCors,
  timeout,
  authenticationRequired,
  forbidden,
  endpointOrResourceNotFound,
  validation,
  conflict,
  databaseUnavailable,
  serverUnavailable,
  invalidResponse,
  requestFailed,
}

class ApiClientException implements Exception {
  const ApiClientException(
    this.message, {
    this.statusCode,
    this.kind = ApiFailureKind.requestFailed,
  });

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  static const configuredBaseUrl = String.fromEnvironment(
    'SAFARSETU_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
          value, 'baseUrl', 'Must be an absolute HTTP or HTTPS API URL.');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty || path == '/') {
      return uri.replace(path: '/api').toString();
    }
    return uri.replace(path: path).toString();
  }

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Object?> getJson(String path,
          {Map<String, String>? queryParameters}) =>
      _request('GET', path, queryParameters: queryParameters);

  Future<Object?> postJson(String path, Object body) =>
      _request('POST', path, body: body);

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    final pathSuffix = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.parse('$_baseUrl/$pathSuffix')
        .replace(queryParameters: queryParameters);
    try {
      final http.Response response;
      if (method == 'GET') {
        response = await _client.get(uri,
            headers: const {'Accept': 'application/json'}).timeout(timeout);
      } else {
        response = await _client
            .post(uri,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode(body))
            .timeout(timeout);
      }
      final Object? decoded;
      try {
        decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw _statusException(response.statusCode);
        }
        throw const ApiClientException(
          'The backend returned a successful response in an invalid format.',
          kind: ApiFailureKind.invalidResponse,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final backendMessage =
            decoded is Map<String, dynamic> && decoded['message'] is String
                ? decoded['message'] as String
                : null;
        throw _statusException(response.statusCode, backendMessage);
      }
      return decoded;
    } on ApiClientException catch (error) {
      _logFailure(method, uri, error.kind, error);
      rethrow;
    } on TimeoutException catch (error) {
      const failure = ApiClientException(
        'The backend request timed out. Check Spring Boot and database responsiveness, then retry.',
        kind: ApiFailureKind.timeout,
      );
      _logFailure(method, uri, failure.kind, error);
      throw failure;
    } on http.ClientException catch (error) {
      const failure = ApiClientException(
        'Could not connect to the backend. Check that it is running at the configured API URL. If it is running, inspect Edge for a CORS block.',
        kind: ApiFailureKind.networkOrCors,
      );
      _logFailure(method, uri, failure.kind, error);
      throw failure;
    } on FormatException catch (error) {
      const failure = ApiClientException(
        'The backend returned an invalid JSON response.',
        kind: ApiFailureKind.invalidResponse,
      );
      _logFailure(method, uri, failure.kind, error);
      throw failure;
    }
  }

  static ApiClientException _statusException(int statusCode,
      [String? backendMessage]) {
    final kind = switch (statusCode) {
      400 => ApiFailureKind.validation,
      401 => ApiFailureKind.authenticationRequired,
      403 => ApiFailureKind.forbidden,
      404 => ApiFailureKind.endpointOrResourceNotFound,
      409 => ApiFailureKind.conflict,
      503 => ApiFailureKind.databaseUnavailable,
      >= 500 => ApiFailureKind.serverUnavailable,
      _ => ApiFailureKind.requestFailed,
    };
    final fallback = switch (statusCode) {
      400 =>
        'The request was rejected. Check the selected values and try again.',
      401 => 'The backend requires authentication. Sign in and retry.',
      403 => 'The backend denied this request.',
      404 => 'The API endpoint or requested record was not found (HTTP 404).',
      409 => 'The backend rejected this conflicting or invalid event.',
      503 =>
        'The backend cannot access its database. Check PostgreSQL and DB configuration.',
      >= 500 => 'The backend encountered a server error (HTTP $statusCode).',
      _ => 'The backend request failed (HTTP $statusCode).',
    };
    final message = backendMessage?.trim();
    return ApiClientException(
      message == null || message.isEmpty ? fallback : message,
      statusCode: statusCode,
      kind: kind,
    );
  }

  static void _logFailure(
      String method, Uri uri, ApiFailureKind kind, Object error) {
    if (kDebugMode) {
      debugPrint('SafarSetu API $method ${uri.origin}${uri.path} failed '
          '($kind): $error');
    }
  }

  void close() => _client.close();
}
