import 'backend_data.dart';
import 'bus.dart';

/// Applies the conservative rules for in-app high-crowding notices.
class CrowdingAdvisor {
  const CrowdingAdvisor._();

  static bool shouldWarn(OccupancyData? occupancy) =>
      (occupancy?.freshnessStatus == 'FRESH' &&
              occupancy?.dataOrigin == 'REAL' ||
          occupancy?.freshnessStatus == 'SIMULATED' &&
              occupancy?.dataOrigin == 'SIMULATED') &&
      (occupancy?.crowdingCategory == 'HIGH' ||
          occupancy?.crowdingCategory == 'NEARLY_FULL') &&
      occupancy?.onboardPassengers != null;

  static List<Bus> alternatives(Bus selected, Iterable<Bus> candidates) {
    final eligible = candidates.where((candidate) {
      final sameJourney = candidate.busId != selected.busId &&
          candidate.boardingStopId == selected.boardingStopId &&
          candidate.destinationStopId == selected.destinationStopId &&
          candidate.safePredictedOccupancy != null;
      if (!sameJourney) return false;
      if (candidate.source == BusDataSource.mock) {
        return candidate.crowdLevel == CrowdLevel.low ||
            candidate.crowdLevel == CrowdLevel.moderate;
      }
      return (candidate.occupancyFreshness == 'FRESH' &&
                  candidate.occupancyDataOrigin == 'REAL' ||
              candidate.occupancyFreshness == 'SIMULATED' &&
                  candidate.occupancyDataOrigin == 'SIMULATED') &&
          (candidate.crowdingCategory == 'LOW' ||
              candidate.crowdingCategory == 'MODERATE');
    }).toList();
    eligible.sort((a, b) =>
        (a.predictedPercent ?? 101).compareTo(b.predictedPercent ?? 101));
    return List.unmodifiable(eligible);
  }
}
