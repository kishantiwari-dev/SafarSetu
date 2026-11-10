import '../models/backend_data.dart';
import 'api_client.dart';

class SimulatedBusOption {
  const SimulatedBusOption({
    required this.busId,
    required this.fleetCode,
    required this.routeId,
    required this.routeName,
  });

  final String busId;
  final String fleetCode;
  final String routeId;
  final String routeName;

  factory SimulatedBusOption.fromJson(Map<String, dynamic> json) =>
      SimulatedBusOption(
        busId: EtmSimulationRepository._requiredString(json, 'busId'),
        fleetCode: EtmSimulationRepository._requiredString(json, 'fleetCode'),
        routeId: EtmSimulationRepository._requiredString(json, 'routeId'),
        routeName: EtmSimulationRepository._requiredString(json, 'routeName'),
      );
}

class SimulatedEventReceipt {
  const SimulatedEventReceipt({
    required this.id,
    required this.eventStatus,
    required this.dataOrigin,
    required this.tripId,
    this.passengerCount,
    this.stopId,
    this.simulatedAlightingPassengers,
    this.alightingMeaning,
    this.bookingReference,
    this.bookingStatus,
  });

  final String id;
  final String eventStatus;
  final String dataOrigin;
  final String tripId;
  final int? passengerCount;
  final String? stopId;
  final int? simulatedAlightingPassengers;
  final String? alightingMeaning;
  final String? bookingReference;
  final String? bookingStatus;

  factory SimulatedEventReceipt.ticket(Map<String, dynamic> json) =>
      SimulatedEventReceipt(
        id: EtmSimulationRepository._requiredString(json, 'ticketId'),
        eventStatus:
            EtmSimulationRepository._requiredString(json, 'eventStatus'),
        dataOrigin: EtmSimulationRepository._requiredString(json, 'dataOrigin'),
        tripId: EtmSimulationRepository._requiredString(json, 'tripId'),
        passengerCount: EtmSimulationRepository._optionalInt(
            json['passengerCount'], 'passengerCount'),
        bookingReference: json['bookingReference'] as String?,
        bookingStatus: json['bookingStatus'] as String?,
      );

  factory SimulatedEventReceipt.arrival(Map<String, dynamic> json) =>
      SimulatedEventReceipt(
        id: EtmSimulationRepository._requiredString(json, 'eventId'),
        eventStatus:
            EtmSimulationRepository._requiredString(json, 'eventStatus'),
        dataOrigin: EtmSimulationRepository._requiredString(json, 'dataOrigin'),
        tripId: EtmSimulationRepository._requiredString(json, 'tripId'),
        stopId: EtmSimulationRepository._requiredString(json, 'stopId'),
        simulatedAlightingPassengers: EtmSimulationRepository._optionalInt(
            json['simulatedAlightingPassengers'],
            'simulatedAlightingPassengers'),
        alightingMeaning: json['alightingMeaning'] as String?,
      );
}

abstract interface class EtmSimulationGateway {
  Future<List<SimulatedBusOption>> listSimulatedBuses();
  Future<List<StopOption>> routeStops(SimulatedBusOption bus);
  Future<SimulatedEventReceipt> submitTicket(
      {required String ticketId,
      required String idempotencyKey,
      required String busId,
      required String boardingStopId,
      required String destinationStopId,
      required int passengerCount,
      required String tripId,
      required DateTime boardedAt,
      String? bookingReference});
  Future<SimulatedEventReceipt> submitArrival(
      {required String eventId,
      required String tripId,
      required String busId,
      required String stopId,
      required DateTime arrivedAt});
  Future<OccupancyData> occupancy(
      {required String busId, required String stopId, required String tripId});
  void close();
}

class EtmSimulationRepository implements EtmSimulationGateway {
  EtmSimulationRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<SimulatedBusOption>> listSimulatedBuses() async {
    final page = _asMap(await _client.getJson(
      'buses',
      queryParameters: const {'page': '0', 'size': '100'},
    ));
    final content = page['content'];
    if (content is! List) {
      throw const FormatException(
          'The backend bus list has an invalid format.');
    }
    return content
        .map(_asMap)
        .where((json) =>
            json['dataOrigin'] == 'SIMULATED' && json['active'] == true)
        .map(SimulatedBusOption.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<StopOption>> routeStops(SimulatedBusOption bus) async {
    final response = await _client.getJson(
      'routes/${Uri.encodeComponent(bus.routeId)}/stops',
    );
    if (response is! List) {
      throw const FormatException('The backend route stop list is invalid.');
    }
    final stops =
        response.map(_asMap).map(StopOption.fromJson).toList(growable: false);
    for (var index = 0; index < stops.length; index++) {
      if (stops[index].stopOrder != index) {
        throw const FormatException(
            'The backend route stops are not in a valid ordered sequence.');
      }
    }
    return stops;
  }

  @override
  Future<SimulatedEventReceipt> submitTicket({
    required String ticketId,
    required String idempotencyKey,
    required String busId,
    required String boardingStopId,
    required String destinationStopId,
    required int passengerCount,
    required String tripId,
    required DateTime boardedAt,
    String? bookingReference,
  }) async {
    final response = _asMap(await _client.postJson('etm/tickets', {
      'ticketId': ticketId,
      'idempotencyKey': idempotencyKey,
      'busId': busId,
      'boardingStopId': boardingStopId,
      'destinationStopId': destinationStopId,
      'passengerCount': passengerCount,
      'tripId': tripId,
      'boardedAt': boardedAt.toUtc().toIso8601String(),
      if (bookingReference != null && bookingReference.trim().isNotEmpty)
        'bookingReference': bookingReference.trim(),
    }));
    return SimulatedEventReceipt.ticket(response);
  }

  @override
  Future<SimulatedEventReceipt> submitArrival({
    required String eventId,
    required String tripId,
    required String busId,
    required String stopId,
    required DateTime arrivedAt,
  }) async {
    final response = _asMap(await _client.postJson('etm/simulated/arrivals', {
      'eventId': eventId,
      'tripId': tripId,
      'busId': busId,
      'stopId': stopId,
      'arrivedAt': arrivedAt.toUtc().toIso8601String(),
    }));
    return SimulatedEventReceipt.arrival(response);
  }

  @override
  Future<OccupancyData> occupancy({
    required String busId,
    required String stopId,
    required String tripId,
  }) async =>
      OccupancyData.fromJson(_asMap(await _client.getJson(
        'buses/${Uri.encodeComponent(busId)}/occupancy',
        queryParameters: {'stopId': stopId, 'tripId': tripId},
      )));

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('The backend response is missing $key.');
    }
    return value;
  }

  static int? _optionalInt(Object? value, String key) {
    if (value == null) return null;
    if (value is! num || !value.isFinite || value % 1 != 0) {
      throw FormatException('The backend response has an invalid $key.');
    }
    return value.toInt();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    throw const FormatException('The backend response has an invalid shape.');
  }

  @override
  void close() => _client.close();
}
