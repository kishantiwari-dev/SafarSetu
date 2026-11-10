import 'package:flutter_test/flutter_test.dart';
import 'package:safarsetu/models/backend_data.dart';
import 'package:safarsetu/models/bus.dart';
import 'package:safarsetu/models/crowding_advisor.dart';

void main() {
  OccupancyData occupancy({
    String freshness = 'FRESH',
    String origin = 'REAL',
    String category = 'HIGH',
    int? passengers = 40,
  }) =>
      OccupancyData(
        busId: 'BUS-1',
        freshnessStatus: freshness,
        dataOrigin: origin,
        crowdingCategory: category,
        onboardPassengers: passengers,
      );

  Bus candidate({
    required String id,
    required String category,
    String freshness = 'FRESH',
    String origin = 'REAL',
    String from = 'STOP-A',
    String to = 'STOP-B',
    int? passengers = 12,
  }) =>
      Bus(
        busId: id,
        route: 'Route',
        capacity: 35,
        totalPassengerCapacity: 50,
        predictedOccupancy: passengers,
        boardingStop: 'Alpha',
        destination: 'Beta',
        boardingStopId: from,
        destinationStopId: to,
        source: BusDataSource.backend,
        crowdingCategory: category,
        occupancyFreshness: freshness,
        occupancyDataOrigin: origin,
      );

  test(
      'crowding alert requires fresh known real or explicitly simulated occupancy',
      () {
    expect(CrowdingAdvisor.shouldWarn(occupancy()), isTrue);
    expect(CrowdingAdvisor.shouldWarn(occupancy(freshness: 'STALE')), isFalse);
    expect(
        CrowdingAdvisor.shouldWarn(
            occupancy(freshness: 'SIMULATED', origin: 'SIMULATED')),
        isTrue);
    expect(CrowdingAdvisor.shouldWarn(occupancy(passengers: null)), isFalse);
  });

  test('alternatives require same journey and fresh known lower crowding', () {
    final selected = candidate(id: 'BUS-1', category: 'HIGH');
    final alternatives = CrowdingAdvisor.alternatives(selected, [
      candidate(id: 'BUS-2', category: 'MODERATE'),
      candidate(id: 'BUS-3', category: 'LOW', freshness: 'STALE'),
      candidate(
          id: 'BUS-4',
          category: 'LOW',
          freshness: 'SIMULATED',
          origin: 'SIMULATED'),
      candidate(id: 'BUS-5', category: 'LOW', passengers: null),
      candidate(id: 'BUS-6', category: 'LOW', to: 'OTHER'),
    ]);
    expect(alternatives.map((bus) => bus.busId), ['BUS-2', 'BUS-4']);
  });
}
