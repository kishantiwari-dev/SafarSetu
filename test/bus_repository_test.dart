import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safarsetu/data/api_bus_repository.dart';
import 'package:safarsetu/data/api_client.dart';
import 'package:safarsetu/data/bus_repository.dart';
import 'package:safarsetu/data/mock_bus_repository.dart';
import 'package:safarsetu/data/simulated_trip_id.dart';
import 'package:safarsetu/models/bus.dart';

void main() {
  test('unknown backend occupancy is not rendered as zero percent', () {
    const bus = Bus(
      busId: 'UNKNOWN',
      route: 'Route',
      capacity: 50,
      totalPassengerCapacity: 55,
      predictedOccupancy: 0,
      boardingStop: 'Alpha',
      destination: 'Beta',
      source: BusDataSource.backend,
      occupancyFreshness: 'UNKNOWN',
    );
    expect(bus.safePredictedOccupancy, isNull);
    expect(bus.predictedPercent, isNull);
    expect(bus.predictedSeatsLeftPercent, isNull);
    expect(bus.crowdLevel, CrowdLevel.unknown);
  });

  final stopPage = {
    'content': [
      {'stopId': 'STOP-A', 'name': 'Alpha'},
      {'stopId': 'STOP-B', 'name': 'Beta'},
    ],
  };
  final busPage = {
    'content': [
      {
        'busId': 'BUS-1',
        'routeId': 'ROUTE-1',
        'routeName': 'Alpha - Beta',
        'seatingCapacity': 40,
        'totalPassengerCapacity': 48,
        'dataOrigin': 'REAL',
      },
    ],
  };

  test('API repository searches by selected stop IDs and maps buses', () async {
    var sawSearch = false;
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/stops') {
          return http.Response(jsonEncode(stopPage), 200);
        }
        if (request.url.path == '/api/buses/search') {
          sawSearch = true;
          expect(request.url.queryParameters['fromStopId'], 'STOP-A');
          expect(request.url.queryParameters['toStopId'], 'STOP-B');
          return http.Response(jsonEncode(busPage), 200);
        }
        return http.Response('', 404);
      }),
    ));

    final buses = await repository.searchBuses(
        boardingStop: 'Alpha', destination: 'Beta');
    expect(sawSearch, isTrue);
    expect(buses, hasLength(1));
    expect(buses.single.source, BusDataSource.backend);
    expect(buses.single.busId, 'BUS-1');
    expect(buses.single.predictedOccupancy, isNull);
    final byIds = await repository.searchBuses(
        boardingStop: ' stop-a ', destination: 'sToP-b');
    expect(byIds, hasLength(1));
    repository.close();
  });

  test('API repository preserves a successful empty result', () async {
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async => http.Response(
            jsonEncode(
                request.url.path == '/api/stops' ? stopPage : {'content': []}),
            200,
          )),
    ));
    expect(
        await repository.searchBuses(
            boardingStop: 'Alpha', destination: 'Beta'),
        isEmpty);
    repository.close();
  });

  test('API search compares each matching bus using occupancy at selected stop',
      () async {
    var occupancyRequests = 0;
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/stops') {
          return http.Response(jsonEncode(stopPage), 200);
        }
        if (request.url.path == '/api/buses/search') {
          return http.Response(
              jsonEncode({
                'content': [
                  busPage['content']!.first,
                  {...busPage['content']!.first as Map, 'busId': 'BUS-2'}
                ]
              }),
              200);
        }
        if (request.url.path.endsWith('/occupancy')) {
          occupancyRequests++;
          expect(request.url.queryParameters['stopId'], 'STOP-A');
          final second = request.url.path.contains('BUS-2');
          return http.Response(
              jsonEncode({
                'busId': second ? 'BUS-2' : 'BUS-1',
                'stopId': 'STOP-A',
                'onboardPassengers': second ? 9 : 42,
                'ticketDerivedOnboardPassengers': second ? 9 : 42,
                'confirmedReservedPassengers': second ? 5 : null,
                'remainingPassengerCapacity': second ? 34 : null,
                'seatingCapacity': 40,
                'totalPassengerCapacity': 48,
                'provisionalAvailableSeats': second ? 31 : null,
                'occupancyStatus':
                    second ? 'CALCULATED' : 'TRIP_CONTEXT_REQUIRED',
                'tripId': second ? 'TRIP-2' : null,
                'freshnessStatus': second ? 'FRESH' : 'MISSING',
                'crowdingCategory': second ? 'LOW' : 'UNKNOWN',
                'dataOrigin': 'REAL',
                'dataQualityWarnings': [],
              }),
              200);
        }
        return http.Response('', 404);
      }),
    ));

    final buses = await repository.searchBuses(
        boardingStop: 'Alpha', destination: 'Beta');
    expect(occupancyRequests, 2);
    expect(buses.first.predictedOccupancy, isNull);
    expect(buses.first.crowdingCategory, 'UNKNOWN');
    expect(buses.last.predictedOccupancy, 9);
    expect(buses.last.backendAvailableSeats, 31);
    expect(buses.last.confirmedReservedPassengers, 5);
    expect(buses.last.remainingPassengerCapacity, 34);
    expect(buses.last.tripId, 'TRIP-2');
    expect(buses.last.occupancyFreshness, 'FRESH');
    repository.close();
  });

  test('simulated bus occupancy search is scoped to the ETM daily trip',
      () async {
    final simulatedPage = {
      'content': [
        {...busPage['content']!.first as Map, 'dataOrigin': 'SIMULATED'}
      ],
    };
    final tripId = simulatedTripIdForBus('BUS-1');
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/stops') {
          return http.Response(jsonEncode(stopPage), 200);
        }
        if (request.url.path == '/api/buses/search') {
          return http.Response(jsonEncode(simulatedPage), 200);
        }
        if (request.url.path == '/api/buses/BUS-1/occupancy') {
          expect(request.url.queryParameters['stopId'], 'STOP-A');
          expect(request.url.queryParameters['tripId'], tripId);
          return http.Response(
              jsonEncode({
                'busId': 'BUS-1',
                'tripId': tripId,
                'stopId': 'STOP-A',
                'onboardPassengers': 7,
                'seatingCapacity': 40,
                'provisionalAvailableSeats': 33,
                'occupancyStatus': 'CALCULATED',
                'freshnessStatus': 'SIMULATED',
                'crowdingCategory': 'LOW',
              }),
              200);
        }
        return http.Response('', 404);
      }),
    ));

    final buses = await repository.searchBuses(
        boardingStop: 'Alpha', destination: 'Beta');
    expect(buses.single.tripId, tripId);
    expect(buses.single.predictedOccupancy, 7);
    expect(buses.single.backendAvailableSeats, 33);
    repository.close();
  });

  test(
      'API repository maps bus details, ordered stops, occupancy, and simulated location',
      () async {
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/buses/BUS-1':
            return http.Response(
                jsonEncode({
                  'busId': 'BUS-1',
                  'routeId': 'ROUTE-1',
                  'routeName': 'Alpha - Beta',
                  'seatingCapacity': 40,
                  'dataOrigin': 'SIMULATED',
                }),
                200);
          case '/api/routes/ROUTE-1/stops':
            return http.Response(
                jsonEncode([
                  {'stopId': 'STOP-A', 'name': 'Alpha', 'stopOrder': 0},
                  {'stopId': 'STOP-B', 'name': 'Beta', 'stopOrder': 1},
                ]),
                200);
          case '/api/buses/BUS-1/occupancy':
            expect(request.url.queryParameters['stopId'], 'STOP-A');
            return http.Response(
                jsonEncode({
                  'busId': 'BUS-1',
                  'onboardPassengers': 12,
                  'ticketDerivedOnboardPassengers': 12,
                  'confirmedReservedPassengers': 8,
                  'remainingPassengerCapacity': 28,
                  'seatingCapacity': 40,
                  'totalPassengerCapacity': 48,
                  'provisionalAvailableSeats': 28,
                  'seatEstimateAssumption': 'One passenger per seat',
                  'dataQualityWarnings': ['JOURNEY_INSTANCE_UNKNOWN'],
                }),
                200);
          case '/api/buses/BUS-1/location':
            return http.Response(
                jsonEncode({
                  'busId': 'BUS-1',
                  'latitude': 28.4,
                  'longitude': 77.5,
                  'recordedAt': '2026-10-25T10:00:00Z',
                  'dataOrigin': 'SIMULATED',
                  'stale': false,
                  'freshnessStatus': 'FRESH',
                }),
                200);
        }
        return http.Response('', 404);
      }),
    ));
    const bus = Bus(
      busId: 'BUS-1',
      route: 'Alpha - Beta',
      capacity: 40,
      boardingStop: 'Alpha',
      destination: 'Beta',
      routeId: 'ROUTE-1',
      boardingStopId: 'STOP-A',
      destinationStopId: 'STOP-B',
      source: BusDataSource.backend,
    );

    final details = await repository.loadDetails(bus);
    expect(details.orderedStops.map((stop) => stop.stopOrder), [0, 1]);
    expect(details.occupancy?.onboardPassengers, 12);
    expect(details.occupancy?.ticketDerivedOnboardPassengers, 12);
    expect(details.occupancy?.confirmedReservedPassengers, 8);
    expect(details.occupancy?.remainingPassengerCapacity, 28);
    expect(details.occupancy?.provisionalAvailableSeats, 28);
    expect(details.location?.dataOrigin, 'SIMULATED');
    expect(details.location?.freshnessStatus, 'FRESH');
    repository.close();
  });

  test('API mode rejects unselected stop names without mock fallback',
      () async {
    var searchRequests = 0;
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/stops') {
          return http.Response(jsonEncode(stopPage), 200);
        }
        searchRequests++;
        return http.Response(jsonEncode(busPage), 200);
      }),
    ));
    await expectLater(
      repository.searchBuses(boardingStop: 'Unknown', destination: 'Beta'),
      throwsA(isA<BusRepositoryException>()),
    );
    expect(searchRequests, 0);
    expect(repository.isApiBacked, isTrue);
    repository.close();
  });

  test(
      'mock repository keeps arbitrary stop pairs empty and separate from API mode',
      () async {
    const repository = MockBusRepository();
    final buses = await repository.searchBuses(
        boardingStop: 'Alpha', destination: 'Beta');
    expect(repository.isApiBacked, isFalse);
    expect(buses, isEmpty);
  });

  test('demo searches return three ordered distinct simulated trips', () async {
    const repository = MockBusRepository();
    final buses = await repository.searchBuses(
        boardingStop: 'Knowledge Park II', destination: 'Pari Chowk');
    expect(buses, hasLength(3));
    expect(buses.map((bus) => bus.busId).toSet(), hasLength(3));
    expect(buses.map((bus) => bus.tripId).toSet(), hasLength(3));
    expect(
        buses.every((bus) =>
            bus.source == BusDataSource.mock &&
            bus.routeId != null &&
            bus.boardingStopId == 'KP_II' &&
            bus.destinationStopId == 'PARI_CHOWK'),
        isTrue);
    expect(buses.map((bus) => bus.predictedPercent), [36, 64, 96]);
    expect(buses.map((bus) => bus.predictedSeatsLeftPercent), [64, 36, 4]);
    expect(buses.last.crowdLabel, 'Overcrowded');

    final reverse = await repository.searchBuses(
        boardingStop: ' alpha 1 ', destination: 'BOTANICAL GARDEN');
    expect(reverse, hasLength(3));
    expect(reverse.every((bus) => bus.routeId == 'SIM-GN-009'), isTrue);
    expect(
        await repository.searchBuses(
            boardingStop: 'Alpha', destination: 'Beta'),
        isEmpty);
    final reverseSegment = await repository.searchBuses(
        boardingStop: 'Pari Chowk', destination: 'Knowledge Park II');
    expect(reverseSegment, hasLength(3));
    expect(reverseSegment.every((bus) => bus.routeId == 'SIM-GN-009'), isTrue);
  });

  test('mock details keep the selected stops on the associated ordered route',
      () async {
    const repository = MockBusRepository();
    final buses = await repository.searchBuses(
        boardingStop: 'Alpha 1', destination: 'Botanical Garden');
    final details = await repository.loadDetails(buses.first);
    final indexes = details.orderedStops.map((stop) => stop.stopId).toList();
    expect(indexes.indexOf('ALPHA_1'),
        lessThan(indexes.indexOf('BOTANICAL_GARDEN')));
  });

  test('API repository does not substitute mock data after network failure',
      () async {
    final repository = ApiBusRepository(ApiClient(
      baseUrl: 'http://localhost:8080/api',
      client: MockClient((_) async => throw http.ClientException('offline')),
    ));
    await expectLater(
      repository.searchBuses(boardingStop: 'Alpha', destination: 'Beta'),
      throwsA(isA<ApiClientException>()),
    );
    repository.close();
  });
}
