import '../models/bus.dart';
import '../models/backend_data.dart';
import 'bus_repository.dart';

class MockBusRepository implements BusRepository {
  const MockBusRepository();

  static const _stops = <StopOption>[
    StopOption(
        stopId: 'BOTANICAL_GARDEN',
        name: 'Botanical Garden',
        latitude: 28.5647,
        longitude: 77.3340,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_18',
        name: 'Noida Sector 18 / Atta Market',
        latitude: 28.5708,
        longitude: 77.3261,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_62',
        name: 'Noida Sector 62',
        latitude: 28.6270,
        longitude: 77.3725,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_51',
        name: 'Noida Sector 51',
        latitude: 28.5834,
        longitude: 77.3730,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_76',
        name: 'Noida Sector 76',
        latitude: 28.5678,
        longitude: 77.3761,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_137',
        name: 'Noida Sector 137',
        latitude: 28.5065,
        longitude: 77.4050,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_142',
        name: 'Noida Sector 142',
        latitude: 28.4939,
        longitude: 77.4107,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SECTOR_148',
        name: 'Noida Sector 148',
        latitude: 28.4774,
        longitude: 77.4170,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'KP_II',
        name: 'Knowledge Park II',
        latitude: 28.4578,
        longitude: 77.5000,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'PARI_CHOWK',
        name: 'Pari Chowk',
        latitude: 28.4652,
        longitude: 77.5080,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'ALPHA_1',
        name: 'Alpha 1',
        latitude: 28.4712,
        longitude: 77.5070,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'DELTA_1',
        name: 'Delta 1',
        latitude: 28.4772,
        longitude: 77.5140,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'GNIDA',
        name: 'Greater Noida Authority',
        latitude: 28.4740,
        longitude: 77.5030,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'KASNA',
        name: 'Kasna',
        latitude: 28.4070,
        longitude: 77.5050,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SHARDA',
        name: 'Sharda University',
        latitude: 28.4720,
        longitude: 77.4830,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'GBU',
        name: 'Gautam Buddha University',
        latitude: 28.4190,
        longitude: 77.5300,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'SURJPUR',
        name: 'Surajpur',
        latitude: 28.5200,
        longitude: 77.4850,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'DADRI_RAIL',
        name: 'Dadri Railway Station',
        latitude: 28.5525,
        longitude: 77.5545,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'GAUR_CITY',
        name: 'Gaur City',
        latitude: 28.6070,
        longitude: 77.4350,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'KISAN_CHOWK',
        name: 'Kisan Chowk',
        latitude: 28.6130,
        longitude: 77.4490,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'GREATER_NOIDA_WEST',
        name: 'Greater Noida West',
        latitude: 28.5950,
        longitude: 77.4450,
        verificationStatus: 'APPROXIMATE'),
    StopOption(
        stopId: 'DEPOT',
        name: 'Depot Station',
        latitude: 28.4510,
        longitude: 77.5350,
        verificationStatus: 'APPROXIMATE'),
  ];

  static const _routes = <String, List<String>>{
    'SIM-GN-001': [
      'BOTANICAL_GARDEN',
      'SECTOR_18',
      'SECTOR_62',
      'KP_II',
      'PARI_CHOWK',
      'ALPHA_1'
    ],
    'SIM-GN-002': [
      'SECTOR_62',
      'SECTOR_51',
      'SECTOR_76',
      'KP_II',
      'DELTA_1',
      'GNIDA'
    ],
    'SIM-GN-003': [
      'GAUR_CITY',
      'KISAN_CHOWK',
      'GREATER_NOIDA_WEST',
      'SECTOR_51',
      'SECTOR_62'
    ],
    'SIM-GN-004': [
      'KASNA',
      'SHARDA',
      'GBU',
      'SURJPUR',
      'DELTA_1',
      'PARI_CHOWK'
    ],
    'SIM-GN-005': [
      'SECTOR_51',
      'SECTOR_76',
      'SECTOR_137',
      'SECTOR_142',
      'SECTOR_148',
      'KP_II'
    ],
    'SIM-GN-006': [
      'DADRI_RAIL',
      'GBU',
      'KASNA',
      'KP_II',
      'PARI_CHOWK',
      'DEPOT'
    ],
    'SIM-GN-007': [
      'KP_II',
      'PARI_CHOWK',
      'ALPHA_1',
      'DELTA_1',
      'GNIDA',
      'DEPOT'
    ],
    'SIM-GN-008': [
      'SECTOR_18',
      'BOTANICAL_GARDEN',
      'SECTOR_51',
      'GREATER_NOIDA_WEST',
      'GAUR_CITY'
    ],
    // Reverse service exists as a separate ordered route with distinct trips.
    'SIM-GN-009': [
      'ALPHA_1',
      'PARI_CHOWK',
      'KP_II',
      'SECTOR_62',
      'SECTOR_18',
      'BOTANICAL_GARDEN'
    ],
  };

  @override
  bool get isApiBacked => false;

  @override
  Future<List<StopOption>> listStops() async => _stops;

  @override
  Future<List<Bus>> searchBuses(
      {required String boardingStop, required String destination}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final from = _findStop(boardingStop);
    final to = _findStop(destination);
    if (from == null ||
        to == null ||
        from.stopId == to.stopId ||
        boardingStop.toLowerCase().contains('mars') ||
        destination.toLowerCase().contains('mars')) {
      return const [];
    }
    final matchingRoutes = _routes.entries
        .where((entry) => _onRoute(entry.key, from.stopId, to.stopId));
    final matchingRoute = matchingRoutes.isEmpty ? null : matchingRoutes.first;
    if (matchingRoute == null) return const [];
    // Three distinct deterministic demo trips share the valid route/stop sequence.
    // Counts represent 36%, 64%, and 96% occupancy of 50 seats.
    const specs = <({String bus, String trip, int passengers, int eta})>[
      (bus: 'BUS-DEMO-A', trip: 'TRIP-DEMO-A-01', passengers: 18, eta: 6),
      (bus: 'BUS-DEMO-B', trip: 'TRIP-DEMO-B-01', passengers: 32, eta: 10),
      (bus: 'BUS-DEMO-C', trip: 'TRIP-DEMO-C-01', passengers: 48, eta: 4),
    ];
    return [
      for (final spec in specs)
        Bus(
          busId: spec.bus,
          route: 'SIMULATED ${matchingRoute.key} corridor',
          currentOccupancy: spec.passengers,
          capacity: 50,
          totalPassengerCapacity: 50,
          predictedOccupancy: spec.passengers,
          etaMinutes: spec.eta,
          boardingStop: from.name,
          destination: to.name,
          source: BusDataSource.mock,
          dataOrigin: 'SIMULATED',
          routeId: matchingRoute.key,
          boardingStopId: from.stopId,
          destinationStopId: to.stopId,
          tripId: spec.trip,
          recommendation: spec.passengers >= 45
              ? 'Very limited seats likely available'
              : 'Simulated passenger estimate at your boarding stop',
        ),
    ];
  }

  bool _onRoute(String routeId, String from, String to) {
    final route = _routes[routeId]!;
    final fromIndex = route.indexOf(from);
    final toIndex = route.indexOf(to);
    return fromIndex >= 0 && toIndex > fromIndex;
  }

  StopOption? _findStop(String name) {
    final normalized = name.trim().toLowerCase();
    for (final stop in _stops) {
      if (stop.name.toLowerCase() == normalized ||
          stop.stopId.toLowerCase() == normalized) {
        return stop;
      }
    }
    return null;
  }

  @override
  Future<BusDetailsData> loadDetails(Bus bus) async {
    final sequence = _routes[bus.routeId];
    final stops = sequence == null
        ? const <StopOption>[]
        : [
            for (var i = 0; i < sequence.length; i++)
              _stops.firstWhere((s) => s.stopId == sequence[i]).copyWithOrder(i)
          ];
    final isMissing = bus.busId == 'BUS-SIM-005';
    final isStale = bus.busId == 'BUS-SIM-008';
    final locationStop = isStale
        ? _stops.firstWhere((s) => s.stopId == 'SECTOR_18')
        : stops.isEmpty
            ? null
            : stops[stops.length ~/ 2];
    final location = isMissing || locationStop == null
        ? null
        : BusLocationData(
            busId: bus.busId,
            latitude: locationStop.latitude!,
            longitude: locationStop.longitude!,
            recordedAt: DateTime.now().toUtc().subtract(
                Duration(hours: isStale ? 24 : 0, minutes: isStale ? 0 : 8)),
            dataOrigin: 'SIMULATED',
            stale: isStale,
            freshnessStatus: 'SIMULATED',
          );
    return BusDetailsData(
      bus: bus,
      orderedStops: stops,
      location: location,
      locationMessage:
          isMissing ? 'No simulated location is recorded for this bus.' : null,
    );
  }

  @override
  void close() {}
}

extension on StopOption {
  StopOption copyWithOrder(int order) => StopOption(
        stopId: stopId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        verificationStatus: verificationStatus,
        stopOrder: order,
      );
}
