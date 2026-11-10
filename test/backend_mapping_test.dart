import 'package:flutter_test/flutter_test.dart';
import 'package:safarsetu/models/bus.dart';
import 'package:safarsetu/models/backend_data.dart';

void main() {
  test('maps backend bus metadata without inventing occupancy or ETA', () {
    final bus = Bus.fromBackendJson(
      {
        'busId': 'BUS-1',
        'routeId': 'ROUTE-1',
        'routeName': 'Aqua route',
        'seatingCapacity': 40,
        'dataOrigin': 'SIMULATED'
      },
      boardingStop: 'Alpha',
      destination: 'Beta',
      boardingStopId: 'STOP-A',
      destinationStopId: 'STOP-B',
    );

    expect(bus.source, BusDataSource.backend);
    expect(bus.boardingStopId, 'STOP-A');
    expect(bus.predictedOccupancy, isNull);
    expect(bus.etaMinutes, isNull);
    expect(bus.predictedAvailableSeats, isNull);
    expect(bus.crowdLevel, CrowdLevel.unknown);
  });

  test('maps unknown occupancy and provisional seat estimates', () {
    final occupancy = OccupancyData.fromJson({
      'busId': 'BUS-1',
      'tripId': 'TRIP-1',
      'onboardPassengers': null,
      'provisionalAvailableSeats': null,
      'occupancyStatus': 'UNKNOWN',
      'freshnessStatus': 'MISSING',
      'crowdingCategory': 'UNKNOWN',
      'dataQualityWarnings': ['NO_TICKET_DATA'],
    });

    expect(occupancy.onboardPassengers, isNull);
    expect(occupancy.tripId, 'TRIP-1');
    expect(occupancy.provisionalAvailableSeats, isNull);
    expect(occupancy.freshnessStatus, 'MISSING');
    expect(occupancy.crowdingCategory, 'UNKNOWN');
    expect(occupancy.dataQualityWarnings, ['NO_TICKET_DATA']);
    expect(occupancy.ticketDerivedOnboardPassengers, isNull);
    expect(occupancy.confirmedReservedPassengers, isNull);
    expect(occupancy.remainingPassengerCapacity, isNull);
  });

  test('maps booking-aware occupancy while retaining legacy onboard field', () {
    final occupancy = OccupancyData.fromJson({
      'busId': 'BUS-1',
      'tripId': 'TRIP-1',
      'onboardPassengers': 7,
      'ticketDerivedOnboardPassengers': 7,
      'confirmedReservedPassengers': 4,
      'totalPassengerCapacity': 20,
      'remainingPassengerCapacity': 9,
    });

    expect(occupancy.onboardPassengers, 7);
    expect(occupancy.ticketDerivedOnboardPassengers, 7);
    expect(occupancy.confirmedReservedPassengers, 4);
    expect(occupancy.totalPassengerCapacity, 20);
    expect(occupancy.remainingPassengerCapacity, 9);
  });

  test('rejects malformed backend bus capacity', () {
    expect(
      () => Bus.fromBackendJson(
        {
          'busId': 'BUS-1',
          'routeId': 'R',
          'routeName': 'Route',
          'seatingCapacity': '40'
        },
        boardingStop: 'Alpha',
        destination: 'Beta',
        boardingStopId: 'A',
        destinationStopId: 'B',
      ),
      throwsFormatException,
    );
  });

  test(
      'invalid simulated occupancy is withheld and does not produce negative seat estimates',
      () {
    const invalid = Bus(
      busId: 'BUS-SIM-009',
      route: 'SIMULATED route',
      currentOccupancy: 65,
      predictedOccupancy: 65,
      capacity: 35,
      totalPassengerCapacity: 50,
      boardingStop: 'Knowledge Park II',
      destination: 'Pari Chowk',
    );
    expect(invalid.safePredictedOccupancy, isNull);
    expect(invalid.predictedPercent, isNull);
    expect(invalid.predictedAvailableSeats, isNull);
    expect(invalid.crowdLevel, CrowdLevel.unknown);
  });
}
