import 'bus.dart';

int? _optionalInt(Object? value, String field) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value % 1 != 0) {
    throw FormatException('Expected an integer for $field.');
  }
  return value.toInt();
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $field in backend response.');
  }
  return value;
}

class StopOption {
  const StopOption({
    required this.stopId,
    required this.name,
    this.latitude,
    this.longitude,
    this.verificationStatus,
    this.stopOrder,
  });

  final String stopId;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? verificationStatus;
  final int? stopOrder;

  factory StopOption.fromJson(Map<String, dynamic> json) => StopOption(
        stopId: _requiredString(json, 'stopId'),
        name: _requiredString(json, 'name'),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        verificationStatus: json['verificationStatus'] as String?,
        stopOrder: _optionalInt(json['stopOrder'], 'stopOrder'),
      );
}

class OccupancyData {
  const OccupancyData({
    required this.busId,
    this.tripId,
    this.routeId,
    this.stopId,
    this.stopName,
    this.stopOrder,
    this.calculatedAt,
    this.onboardPassengers,
    this.ticketDerivedOnboardPassengers,
    this.confirmedReservedPassengers,
    this.remainingPassengerCapacity,
    this.seatingCapacity,
    this.totalPassengerCapacity,
    this.provisionalAvailableSeats,
    this.calculationConvention,
    this.occupancyStatus,
    this.seatEstimateAssumption,
    this.dataQualityWarnings = const [],
    this.dataOrigin,
    this.dataUpdatedAt,
    this.freshnessStatus = 'UNKNOWN',
    this.crowdingCategory = 'UNKNOWN',
  });

  final String busId;
  final String? tripId;
  final String? routeId;
  final String? stopId;
  final String? stopName;
  final int? stopOrder;
  final DateTime? calculatedAt;
  final int? onboardPassengers;
  final int? ticketDerivedOnboardPassengers;
  final int? confirmedReservedPassengers;
  final int? remainingPassengerCapacity;
  final int? seatingCapacity;
  final int? totalPassengerCapacity;
  final int? provisionalAvailableSeats;
  final String? calculationConvention;
  final String? occupancyStatus;
  final String? seatEstimateAssumption;
  final List<String> dataQualityWarnings;
  final String? dataOrigin;
  final DateTime? dataUpdatedAt;
  final String freshnessStatus;
  final String crowdingCategory;

  factory OccupancyData.fromJson(Map<String, dynamic> json) => OccupancyData(
        busId: _requiredString(json, 'busId'),
        tripId: json['tripId'] as String?,
        routeId: json['routeId'] as String?,
        stopId: json['stopId'] as String?,
        stopName: json['stopName'] as String?,
        stopOrder: _optionalInt(json['stopOrder'], 'stopOrder'),
        calculatedAt: DateTime.tryParse(json['calculatedAt'] as String? ?? ''),
        dataUpdatedAt:
            DateTime.tryParse(json['dataUpdatedAt'] as String? ?? ''),
        freshnessStatus: json['freshnessStatus'] as String? ?? 'UNKNOWN',
        crowdingCategory: json['crowdingCategory'] as String? ?? 'UNKNOWN',
        onboardPassengers:
            _optionalInt(json['onboardPassengers'], 'onboardPassengers'),
        ticketDerivedOnboardPassengers: _optionalInt(
                json['ticketDerivedOnboardPassengers'],
                'ticketDerivedOnboardPassengers') ??
            _optionalInt(json['onboardPassengers'], 'onboardPassengers'),
        confirmedReservedPassengers: _optionalInt(
            json['confirmedReservedPassengers'], 'confirmedReservedPassengers'),
        remainingPassengerCapacity: _optionalInt(
            json['remainingPassengerCapacity'], 'remainingPassengerCapacity'),
        seatingCapacity:
            _optionalInt(json['seatingCapacity'], 'seatingCapacity'),
        totalPassengerCapacity: _optionalInt(
            json['totalPassengerCapacity'], 'totalPassengerCapacity'),
        provisionalAvailableSeats: _optionalInt(
            json['provisionalAvailableSeats'], 'provisionalAvailableSeats'),
        calculationConvention: json['calculationConvention'] as String?,
        occupancyStatus: json['occupancyStatus'] as String?,
        seatEstimateAssumption: json['seatEstimateAssumption'] as String?,
        dataQualityWarnings:
            (json['dataQualityWarnings'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(growable: false),
        dataOrigin: json['dataOrigin'] as String?,
      );
}

class BusLocationData {
  const BusLocationData({
    required this.busId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.dataOrigin,
    required this.stale,
    required this.freshnessStatus,
  });

  final String busId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String dataOrigin;
  final bool stale;
  final String freshnessStatus;

  factory BusLocationData.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final recordedAt = DateTime.tryParse(json['recordedAt'] as String? ?? '');
    if (latitude is! num || longitude is! num || recordedAt == null) {
      throw const FormatException(
          'The backend location response is incomplete.');
    }
    return BusLocationData(
      busId: _requiredString(json, 'busId'),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      recordedAt: recordedAt,
      dataOrigin: _requiredString(json, 'dataOrigin'),
      stale: json['stale'] == true,
      freshnessStatus: json['freshnessStatus'] as String? ?? 'UNKNOWN',
    );
  }
}

class BusDetailsData {
  const BusDetailsData({
    required this.bus,
    this.orderedStops = const [],
    this.occupancy,
    this.location,
    this.locationMessage,
  });

  final Bus bus;
  final List<StopOption> orderedStops;
  final OccupancyData? occupancy;
  final BusLocationData? location;
  final String? locationMessage;

  factory BusDetailsData.mock(Bus bus) => BusDetailsData(bus: bus);
}
