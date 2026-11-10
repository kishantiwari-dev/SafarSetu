import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safarsetu/data/api_client.dart';
import 'package:safarsetu/data/etm_simulation_repository.dart';

void main() {
  test('bus selection is limited to active SIMULATED backend buses', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/buses');
        expect(request.url.queryParameters['size'], '100');
        expect(request.url.queryParameters.containsKey('sort'), isFalse);
        return http.Response(
            jsonEncode({
              'content': [
                {
                  'busId': 'BUS-SIM-1',
                  'fleetCode': 'SIM-1',
                  'routeId': 'r1',
                  'routeName': 'Route 1',
                  'dataOrigin': 'SIMULATED',
                  'active': true
                },
                {
                  'busId': 'BUS-REAL-1',
                  'fleetCode': 'REAL-1',
                  'routeId': 'r2',
                  'routeName': 'Route 2',
                  'dataOrigin': 'REAL',
                  'active': true
                },
                {
                  'busId': 'BUS-SIM-2',
                  'fleetCode': 'SIM-2',
                  'routeId': 'r3',
                  'routeName': 'Route 3',
                  'dataOrigin': 'SIMULATED',
                  'active': false
                },
              ],
            }),
            200);
      }),
    );
    final buses = await EtmSimulationRepository(client).listSimulatedBuses();
    expect(buses.map((bus) => bus.busId), ['BUS-SIM-1']);
    client.close();
  });

  test('route stops preserve backend order', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async => http.Response(
          jsonEncode([
            {'stopId': 'a', 'name': 'A', 'stopOrder': 0},
            {'stopId': 'b', 'name': 'B', 'stopOrder': 1},
          ]),
          200)),
    );
    final stops = await EtmSimulationRepository(client).routeStops(
      const SimulatedBusOption(
          busId: 'BUS-SIM-1',
          fleetCode: 'SIM-1',
          routeId: 'r1',
          routeName: 'Route 1'),
    );
    expect(stops.map((stop) => stop.stopId), ['a', 'b']);
    client.close();
  });

  test('ticket submission uses the backend DTO contract and parses its receipt',
      () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/etm/tickets');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {
          'ticketId',
          'idempotencyKey',
          'busId',
          'boardingStopId',
          'destinationStopId',
          'passengerCount',
          'tripId',
          'boardedAt',
          'bookingReference'
        });
        expect(body['passengerCount'], 2);
        expect(body['bookingReference'], 'ATM-ABC');
        return http.Response(
            jsonEncode({
              'ticketId': 'SIM-TKT-1',
              'busId': 'BUS-SIM-1',
              'tripId': 'trip-1',
              'passengerCount': 2,
              'dataOrigin': 'SIMULATED',
              'eventStatus': 'ACCEPTED',
              'bookingReference': 'ATM-ABC',
              'bookingStatus': 'BOARDING_RECORDED_SIMULATION',
              'boardedAt': '2026-10-26T00:00:00Z'
            }),
            201);
      }),
    );
    final receipt = await EtmSimulationRepository(client).submitTicket(
      ticketId: 'SIM-TKT-1',
      idempotencyKey: 'IDEM-SIM-TKT-1',
      busId: 'BUS-SIM-1',
      boardingStopId: 'a',
      destinationStopId: 'b',
      passengerCount: 2,
      tripId: 'trip-1',
      boardedAt: DateTime.utc(2026, 10, 26),
      bookingReference: 'ATM-ABC',
    );
    expect(receipt.id, 'SIM-TKT-1');
    expect(receipt.eventStatus, 'ACCEPTED');
    expect(receipt.dataOrigin, 'SIMULATED');
    expect(receipt.bookingReference, 'ATM-ABC');
    expect(receipt.bookingStatus, 'BOARDING_RECORDED_SIMULATION');
    client.close();
  });

  test(
      'arrival submission uses the backend DTO contract and parses expected alighting',
      () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/etm/simulated/arrivals');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys.toSet(),
            {'eventId', 'tripId', 'busId', 'stopId', 'arrivedAt'});
        return http.Response(
            jsonEncode({
              'eventId': 'SIM-ARR-1',
              'busId': 'BUS-SIM-1',
              'tripId': 'trip-1',
              'stopId': 'b',
              'stopOrder': 1,
              'arrivedAt': '2026-10-26T00:00:00Z',
              'simulatedAlightingPassengers': 2,
              'eventStatus': 'ACCEPTED',
              'dataOrigin': 'SIMULATED',
              'alightingMeaning': 'SIMULATED_EXPECTED_ALIGHTING',
              'occupancy': null
            }),
            201);
      }),
    );
    final receipt = await EtmSimulationRepository(client).submitArrival(
      eventId: 'SIM-ARR-1',
      tripId: 'trip-1',
      busId: 'BUS-SIM-1',
      stopId: 'b',
      arrivedAt: DateTime.utc(2026, 10, 26),
    );
    expect(receipt.id, 'SIM-ARR-1');
    expect(receipt.simulatedAlightingPassengers, 2);
    expect(receipt.alightingMeaning, 'SIMULATED_EXPECTED_ALIGHTING');
    client.close();
  });

  test('occupancy refresh sends bus, stop, and trip context', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/buses/BUS-SIM-1/occupancy');
        expect(
            request.url.queryParameters, {'stopId': 'b', 'tripId': 'trip-1'});
        return http.Response(
            jsonEncode({
              'busId': 'BUS-SIM-1',
              'tripId': 'trip-1',
              'stopId': 'b',
              'onboardPassengers': 2,
              'seatingCapacity': 20,
              'provisionalAvailableSeats': 18,
              'dataOrigin': 'SIMULATED',
              'occupancyStatus': 'CALCULATED',
              'freshnessStatus': 'SIMULATED',
              'crowdingCategory': 'LOW'
            }),
            200);
      }),
    );
    final occupancy = await EtmSimulationRepository(client)
        .occupancy(busId: 'BUS-SIM-1', stopId: 'b', tripId: 'trip-1');
    expect(occupancy.onboardPassengers, 2);
    expect(occupancy.dataOrigin, 'SIMULATED');
    client.close();
  });
}
