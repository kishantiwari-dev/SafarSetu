import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safarsetu_atm/src/atm_api.dart';

void main() {
  test('loads paginated backend stops using the actual DTO fields', () async {
    final api = AtmApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/stops');
        expect(request.url.queryParameters['size'], '100');
        return http.Response(
          jsonEncode({
            'content': [
              {'stopId': 'A', 'name': 'Alpha', 'stopOrder': 0},
            ],
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8080/api',
    );

    final stops = await api.loadStops();
    expect(stops.single.id, 'A');
    expect(stops.single.name, 'Alpha');
  });

  test('filters non-simulated or inactive buses from API search', () async {
    final api = AtmApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/buses/search');
        expect(request.url.queryParameters['fromStopId'], 'A');
        expect(request.url.queryParameters['toStopId'], 'B');
        return http.Response(
          jsonEncode({
            'content': [
              {
                'busId': 'sim-1',
                'fleetCode': 'S1',
                'routeId': 'R',
                'routeName': 'Route',
                'totalPassengerCapacity': 40,
                'dataOrigin': 'SIMULATED',
                'active': true,
              },
              {
                'busId': 'inactive',
                'fleetCode': 'S2',
                'routeId': 'R',
                'routeName': 'Route',
                'totalPassengerCapacity': 40,
                'dataOrigin': 'SIMULATED',
                'active': false,
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8080/api',
    );

    final buses = await api.searchBuses(fromStopId: 'A', toStopId: 'B');
    expect(buses.map((bus) => bus.id), ['sim-1']);
    expect(buses.single.demoTripId, 'SIM-TRIP-sim-1-DEMO-01');
  });

  test(
    'submits the booking contract and parses the accepted server receipt',
    () async {
      final api = AtmApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/atm/bookings');
          expect(request.headers['Idempotency-Key'], 'retry-key');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['passengerCount'], 2);
          expect(body['tripId'], 'SIM-TRIP-BUS-1-DEMO-01');
          return http.Response(
            jsonEncode({
              'bookingReference': 'ATM-123',
              'bookingId': 'id-123',
              'tripId': body['tripId'],
              'busId': 'BUS-1',
              'boardingStopId': 'A',
              'boardingStopName': 'Alpha',
              'destinationStopId': 'B',
              'destinationStopName': 'Beta',
              'passengerCount': 2,
              'bookingStatus': 'CONFIRMED_SIMULATION',
              'dataOrigin': 'SIMULATED',
              'boardingStatus': 'NOT_BOARDING_EVIDENCE',
              'createdAt': '2026-10-26T10:00:00Z',
            }),
            201,
          );
        }),
        baseUrl: 'http://localhost:8080/api',
      );
      const bus = AtmBus(
        id: 'BUS-1',
        fleetCode: 'F1',
        routeId: 'R1',
        routeName: 'Route',
        capacity: 40,
        origin: 'SIMULATED',
        active: true,
      );
      const from = AtmStop(id: 'A', name: 'Alpha');
      const to = AtmStop(id: 'B', name: 'Beta');

      final receipt = await api.createBooking(
        idempotencyKey: 'retry-key',
        bus: bus,
        from: from,
        to: to,
        passengerCount: 2,
      );
      expect(receipt.reference, 'ATM-123');
      expect(receipt.status, 'CONFIRMED_SIMULATION');
      expect(receipt.passengerCount, 2);
    },
  );
}
