import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safarsetu/data/api_client.dart';

void main() {
  test('decodes JSON and encodes query parameters', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/stops');
        expect(request.url.queryParameters['page'], '0');
        return http.Response(jsonEncode({'content': []}), 200);
      }),
    );
    expect(await client.getJson('stops', queryParameters: const {'page': '0'}),
        {'content': []});
    client.close();
  });

  test('adds /api when configured with only the backend origin', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        expect(request.url.path, '/api/health');
        return http.Response(jsonEncode({'status': 'UP'}), 200);
      }),
    );
    expect(await client.getJson('health'), {'status': 'UP'});
    client.close();
  });

  test('surfaces structured backend errors and classifies missing records',
      () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((_) async =>
          http.Response(jsonEncode({'message': 'Unknown stop'}), 404)),
    );
    await expectLater(
        client.getJson('stops'),
        throwsA(isA<ApiClientException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.kind, 'kind',
                ApiFailureKind.endpointOrResourceNotFound)
            .having((error) => error.message, 'message', 'Unknown stop')));
    client.close();
  });

  test('identifies database failures returned as HTTP 503', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((_) async => http.Response(
          jsonEncode({'message': 'The database is temporarily unavailable'}),
          503)),
    );
    await expectLater(
        client.getJson('health'),
        throwsA(isA<ApiClientException>().having((error) => error.kind, 'kind',
            ApiFailureKind.databaseUnavailable)));
    client.close();
  });

  test('classifies authorization errors', () async {
    for (final entry in <(int, ApiFailureKind)>[
      (401, ApiFailureKind.authenticationRequired),
      (403, ApiFailureKind.forbidden),
    ]) {
      final client = ApiClient(
        baseUrl: 'http://localhost:8080/api',
        client: MockClient((_) async => http.Response('{}', entry.$1)),
      );
      await expectLater(
          client.getJson('stops'),
          throwsA(isA<ApiClientException>()
              .having((error) => error.kind, 'kind', entry.$2)));
      client.close();
    }
  });

  test('classifies invalid successful JSON', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((_) async => http.Response('not json', 200)),
    );
    await expectLater(
        client.getJson('stops'),
        throwsA(isA<ApiClientException>().having(
            (error) => error.kind, 'kind', ApiFailureKind.invalidResponse)));
    client.close();
  });

  test('classifies browser network and CORS failures', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async =>
          throw http.ClientException('Failed to fetch', request.url)),
    );
    await expectLater(
        client.getJson('stops'),
        throwsA(isA<ApiClientException>().having(
            (error) => error.kind, 'kind', ApiFailureKind.networkOrCors)));
    client.close();
  });

  test('classifies an unresponsive request as a timeout', () async {
    final pendingResponse = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => pendingResponse.future),
    );
    await expectLater(
        client.getJson('stops'),
        throwsA(isA<ApiClientException>()
            .having((error) => error.kind, 'kind', ApiFailureKind.timeout)));
    client.close();
  });
}
