import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safarsetu_atm/src/atm_api.dart';
import 'package:safarsetu_atm/src/atm_app.dart';

void main() {
  testWidgets('shows backend sourced journey inputs and simulation limits', (
    tester,
  ) async {
    final api = AtmApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'content': [
              {'stopId': 'A', 'name': 'Alpha', 'stopOrder': null},
              {'stopId': 'B', 'name': 'Beta', 'stopOrder': null},
            ],
          }),
          200,
        ),
      ),
      baseUrl: 'http://localhost:8080/api',
    );
    await tester.pumpWidget(AtmApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Passenger ticket kiosk'), findsOneWidget);
    expect(find.text('Boarding stop'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(
      find.textContaining('No schedule or fare data is configured'),
      findsOneWidget,
    );
  });
}
