import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safarsetu/models/bus.dart';
import 'package:safarsetu/widgets/bus_card.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('bus search card labels reservations separately from occupancy',
      (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    const bus = Bus(
      busId: 'BUS-1',
      route: 'Route One',
      capacity: 30,
      totalPassengerCapacity: 40,
      predictedOccupancy: 12,
      boardingStop: 'Alpha',
      destination: 'Beta',
      source: BusDataSource.backend,
      tripId: 'trip-1',
      backendAvailableSeats: 18,
      confirmedReservedPassengers: 5,
      remainingPassengerCapacity: 23,
      occupancyFreshness: 'SIMULATED',
      occupancyDataOrigin: 'SIMULATED',
      occupancyStatus: 'CALCULATED',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BusCard(bus: bus, onTap: () {})),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ticket-derived onboard estimate: 12'), findsOneWidget);
    expect(find.text('Confirmed reservations: 5'), findsOneWidget);
    expect(find.text('Passenger capacity remaining: 23'), findsOneWidget);
    expect(find.text('18 / 30 seats'), findsOneWidget);
    expect(find.text('18 seats · 60% provisionally available'), findsOneWidget);
  });
}
