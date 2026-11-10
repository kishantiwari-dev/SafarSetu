import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safarsetu/data/api_client.dart';
import 'package:safarsetu/data/etm_simulation_repository.dart';
import 'package:safarsetu/models/backend_data.dart';
import 'package:safarsetu/screens/etm/etm_simulation_screen.dart';

class _FakeGateway implements EtmSimulationGateway {
  int occupancyCalls = 0;
  bool failRefresh = false;
  bool failArrival = false;
  final bus = const SimulatedBusOption(
      busId: 'BUS-SIM-1',
      fleetCode: 'SIM-1',
      routeId: 'r1',
      routeName: 'Route 1');
  final stops = const [
    StopOption(stopId: 'a', name: 'A', stopOrder: 0),
    StopOption(stopId: 'b', name: 'B', stopOrder: 1),
    StopOption(stopId: 'c', name: 'C', stopOrder: 2),
  ];

  @override
  Future<List<SimulatedBusOption>> listSimulatedBuses() async => [bus];
  @override
  Future<List<StopOption>> routeStops(SimulatedBusOption selected) async =>
      stops;
  @override
  Future<SimulatedEventReceipt> submitTicket(
          {required String ticketId,
          required String idempotencyKey,
          required String busId,
          required String boardingStopId,
          required String destinationStopId,
          required int passengerCount,
          required String tripId,
          required DateTime boardedAt,
          String? bookingReference}) async =>
      SimulatedEventReceipt.ticket({
        'ticketId': ticketId,
        'eventStatus': 'ACCEPTED',
        'dataOrigin': 'SIMULATED',
        'tripId': tripId,
        'passengerCount': passengerCount
      });
  @override
  Future<SimulatedEventReceipt> submitArrival(
      {required String eventId,
      required String tripId,
      required String busId,
      required String stopId,
      required DateTime arrivedAt}) async {
    if (failArrival) {
      throw const ApiClientException(
          'Arrival must advance through the route and time',
          statusCode: 409);
    }
    return SimulatedEventReceipt.arrival({
      'eventId': eventId,
      'eventStatus': 'ACCEPTED',
      'dataOrigin': 'SIMULATED',
      'tripId': tripId,
      'stopId': stopId,
      'simulatedAlightingPassengers': 0,
      'alightingMeaning': 'SIMULATED_EXPECTED_ALIGHTING'
    });
  }

  @override
  Future<OccupancyData> occupancy(
      {required String busId,
      required String stopId,
      required String tripId}) async {
    occupancyCalls++;
    if (failRefresh) {
      throw const ApiClientException('The backend is temporarily unavailable.',
          statusCode: 503);
    }
    return OccupancyData(
        busId: busId,
        tripId: tripId,
        stopId: stopId,
        stopName: 'A',
        onboardPassengers: 1,
        seatingCapacity: 20,
        provisionalAvailableSeats: 19,
        dataOrigin: 'SIMULATED',
        occupancyStatus: 'CALCULATED',
        freshnessStatus: 'SIMULATED',
        crowdingCategory: 'LOW');
  }

  @override
  void close() {}
}

void main() {
  testWidgets(
      'accepted ticket shows backend receipt and refreshes scoped occupancy',
      (tester) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(MaterialApp(
        home: EtmSimulationScreen(apiEnabled: true, gateway: gateway)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Submit simulated ticket'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit simulated ticket'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ticket accepted · SIMULATED'), findsOneWidget);
    expect(find.textContaining('Ticket SIM-TKT-'), findsOneWidget);
    expect(find.textContaining('Ticket-derived estimate: 1 passengers'),
        findsOneWidget);
    expect(gateway.occupancyCalls, 1);
  });

  testWidgets('refresh failure preserves the accepted ticket receipt',
      (tester) async {
    final gateway = _FakeGateway()..failRefresh = true;
    await tester.pumpWidget(MaterialApp(
        home: EtmSimulationScreen(apiEnabled: true, gateway: gateway)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Submit simulated ticket'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit simulated ticket'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ticket accepted · SIMULATED'), findsOneWidget);
    expect(find.textContaining('Occupancy refresh failed'), findsOneWidget);
  });

  testWidgets('arrival conflict displays the backend backward-order message',
      (tester) async {
    final gateway = _FakeGateway()..failArrival = true;
    await tester.pumpWidget(MaterialApp(
        home: EtmSimulationScreen(apiEnabled: true, gateway: gateway)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Record simulated arrival'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record simulated arrival'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Arrival must advance through the route and time'),
        findsOneWidget);
  });
}
