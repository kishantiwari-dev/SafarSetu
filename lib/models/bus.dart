enum CrowdLevel { low, moderate, high, veryHigh, unknown }

enum BusDataSource { mock, backend }

/// Shared UI crowding thresholds, matching backend `safarsetu.crowding` defaults.
class CrowdingThresholds {
  static const moderate = 40;
  static const crowded = 70;
  static const overcrowded = 90;
}

class Bus {
  const Bus({
    required this.busId,
    required this.route,
    this.currentOccupancy,
    required this.capacity,
    this.predictedOccupancy,
    this.etaMinutes,
    this.etaStatus,
    this.etaDataOrigin,
    this.etaAssumption,
    required this.boardingStop,
    required this.destination,
    this.currentLocation,
    this.recommendation,
    this.source = BusDataSource.mock,
    this.dataOrigin,
    this.routeId,
    this.boardingStopId,
    this.destinationStopId,
    this.totalPassengerCapacity,
    this.occupancyFreshness = 'UNKNOWN',
    this.occupancyUpdatedAt,
    this.crowdingCategory = 'UNKNOWN',
    this.tripId,
    this.backendAvailableSeats,
    this.confirmedReservedPassengers,
    this.remainingPassengerCapacity,
    this.occupancyDataOrigin,
    this.occupancyStatus,
  });

  final String busId;
  final String route;
  final int? currentOccupancy;
  final int capacity;
  final int? predictedOccupancy;
  final int? etaMinutes;
  final String? etaStatus;
  final String? etaDataOrigin;
  final String? etaAssumption;
  final String boardingStop;
  final String destination;
  final String? currentLocation;
  final String? recommendation;
  final BusDataSource source;
  final String? dataOrigin;
  final String? routeId;
  final String? boardingStopId;
  final String? destinationStopId;
  final int? totalPassengerCapacity;
  final String occupancyFreshness;
  final DateTime? occupancyUpdatedAt;
  final String crowdingCategory;
  final String? tripId;
  final int? backendAvailableSeats;
  final int? confirmedReservedPassengers;
  final int? remainingPassengerCapacity;
  final String? occupancyDataOrigin;
  final String? occupancyStatus;

  Bus withOccupancy(
          {required int? passengers,
          required int? availableSeats,
          required String freshness,
          required DateTime? updatedAt,
          required String category,
          required String? selectedTripId,
          required String? sourceOrigin,
          required String? status,
          int? reservedPassengers,
          int? remainingCapacity}) =>
      Bus(
        busId: busId,
        route: route,
        currentOccupancy: currentOccupancy,
        capacity: capacity,
        predictedOccupancy: passengers,
        etaMinutes: etaMinutes,
        etaStatus: etaStatus,
        etaDataOrigin: etaDataOrigin,
        etaAssumption: etaAssumption,
        boardingStop: boardingStop,
        destination: destination,
        currentLocation: currentLocation,
        recommendation: recommendation,
        source: source,
        dataOrigin: dataOrigin,
        routeId: routeId,
        boardingStopId: boardingStopId,
        destinationStopId: destinationStopId,
        totalPassengerCapacity: totalPassengerCapacity,
        occupancyFreshness: freshness,
        occupancyUpdatedAt: updatedAt,
        crowdingCategory: category,
        tripId: selectedTripId,
        backendAvailableSeats: availableSeats,
        confirmedReservedPassengers: reservedPassengers,
        remainingPassengerCapacity: remainingCapacity,
        occupancyDataOrigin: sourceOrigin,
        occupancyStatus: status,
      );

  Bus withEta(
          {required int? minutes,
          required String? status,
          required String? dataOrigin,
          required String? assumption}) =>
      Bus(
        busId: busId,
        route: route,
        currentOccupancy: currentOccupancy,
        capacity: capacity,
        predictedOccupancy: predictedOccupancy,
        etaMinutes: minutes,
        etaStatus: status,
        etaDataOrigin: dataOrigin,
        etaAssumption: assumption,
        boardingStop: boardingStop,
        destination: destination,
        currentLocation: currentLocation,
        recommendation: recommendation,
        source: source,
        dataOrigin: this.dataOrigin,
        routeId: routeId,
        boardingStopId: boardingStopId,
        destinationStopId: destinationStopId,
        totalPassengerCapacity: totalPassengerCapacity,
        occupancyFreshness: occupancyFreshness,
        occupancyUpdatedAt: occupancyUpdatedAt,
        crowdingCategory: crowdingCategory,
        tripId: tripId,
        backendAvailableSeats: backendAvailableSeats,
        confirmedReservedPassengers: confirmedReservedPassengers,
        remainingPassengerCapacity: remainingPassengerCapacity,
        occupancyDataOrigin: occupancyDataOrigin,
        occupancyStatus: occupancyStatus,
      );

  bool _validOccupancy(int? count) =>
      count != null &&
      count >= 0 &&
      !(source == BusDataSource.backend &&
          occupancyFreshness != 'FRESH' &&
          occupancyFreshness != 'SIMULATED') &&
      (totalPassengerCapacity == null || count <= totalPassengerCapacity!);
  int? get safePredictedOccupancy =>
      _validOccupancy(predictedOccupancy) ? predictedOccupancy : null;
  int? get safeCurrentOccupancy =>
      _validOccupancy(currentOccupancy) ? currentOccupancy : null;
  int? get predictedAvailableSeats => source == BusDataSource.backend
      ? safePredictedOccupancy == null ||
              backendAvailableSeats == null ||
              backendAvailableSeats! < 0 ||
              backendAvailableSeats! > capacity ||
              backendAvailableSeats !=
                  (capacity - predictedOccupancy!).clamp(0, capacity).toInt()
          ? null
          : backendAvailableSeats
      : safePredictedOccupancy == null || capacity <= 0
          ? null
          : (capacity - safePredictedOccupancy!).clamp(0, capacity).toInt();
  int? get currentPercent => safeCurrentOccupancy == null || capacity <= 0
      ? null
      : (safeCurrentOccupancy! * 100 / capacity).round();
  int? get predictedPercent => safePredictedOccupancy == null || capacity <= 0
      ? null
      : (safePredictedOccupancy! * 100 / capacity).round();
  int? get predictedSeatsLeftPercent =>
      predictedAvailableSeats == null || capacity <= 0
          ? null
          : (predictedAvailableSeats! * 100 / capacity).round();
  CrowdLevel get crowdLevel => predictedPercent == null
      ? CrowdLevel.unknown
      : switch (predictedPercent!) {
          < CrowdingThresholds.moderate => CrowdLevel.low,
          < CrowdingThresholds.crowded => CrowdLevel.moderate,
          < CrowdingThresholds.overcrowded => CrowdLevel.high,
          _ => CrowdLevel.veryHigh,
        };

  String get crowdLabel => switch (crowdLevel) {
        CrowdLevel.low => 'Normal',
        CrowdLevel.moderate => 'Moderately crowded',
        CrowdLevel.high => 'Crowded',
        CrowdLevel.veryHigh => 'Overcrowded',
        CrowdLevel.unknown => 'Occupancy unavailable',
      };

  factory Bus.fromBackendJson(
    Map<String, dynamic> json, {
    required String boardingStop,
    required String destination,
    required String boardingStopId,
    required String destinationStopId,
  }) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
            'Missing or invalid $key in backend bus response.');
      }
      return value;
    }

    final capacity = json['seatingCapacity'];
    final totalCapacity = json['totalPassengerCapacity'];
    if (capacity is! num ||
        !capacity.isFinite ||
        capacity % 1 != 0 ||
        (totalCapacity != null &&
            (totalCapacity is! num ||
                !totalCapacity.isFinite ||
                totalCapacity % 1 != 0))) {
      throw const FormatException('The backend bus capacity is invalid.');
    }
    return Bus(
      busId: requiredString('busId'),
      route: requiredString('routeName'),
      capacity: capacity.toInt(),
      boardingStop: boardingStop,
      destination: destination,
      source: BusDataSource.backend,
      routeId: requiredString('routeId'),
      dataOrigin: json['dataOrigin'] as String? ?? 'UNKNOWN',
      boardingStopId: boardingStopId,
      destinationStopId: destinationStopId,
      totalPassengerCapacity: (totalCapacity as num?)?.toInt(),
    );
  }

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
        busId: json['busId'] as String,
        route: json['route'] as String,
        currentOccupancy: json['currentOccupancy'] as int,
        capacity: json['capacity'] as int,
        predictedOccupancy: json['predictedOccupancy'] as int,
        etaMinutes: json['etaMinutes'] as int,
        boardingStop: json['boardingStop'] as String,
        destination: json['destination'] as String,
        currentLocation: json['currentLocation'] as String,
        recommendation: json['recommendation'] as String,
      );

  Map<String, dynamic> toJson() => {
        'busId': busId,
        'route': route,
        'currentOccupancy': currentOccupancy,
        'capacity': capacity,
        'predictedOccupancy': predictedOccupancy,
        'etaMinutes': etaMinutes,
        'boardingStop': boardingStop,
        'destination': destination,
        'currentLocation': currentLocation,
        'recommendation': recommendation,
      };
}
