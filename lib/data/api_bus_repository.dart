import '../models/backend_data.dart';
import '../models/bus.dart';
import 'api_client.dart';
import 'bus_repository.dart';
import 'simulated_trip_id.dart';

class ApiBusRepository implements BusRepository {
  ApiBusRepository(this._client);

  final ApiClient _client;
  Future<List<StopOption>>? _stopsRequest;

  @override
  bool get isApiBacked => true;

  @override
  Future<List<StopOption>> listStops() async {
    try {
      return await (_stopsRequest ??= _fetchStops());
    } catch (_) {
      _stopsRequest = null;
      rethrow;
    }
  }

  Future<List<StopOption>> _fetchStops() async {
    final page = _asMap(await _client
        .getJson('stops', queryParameters: const {'page': '0', 'size': '100'}));
    final content = page['content'];
    if (content is! List) {
      throw const FormatException(
          'The backend stop list has an invalid format.');
    }
    return content
        .map((entry) => StopOption.fromJson(_asMap(entry)))
        .toList(growable: false);
  }

  @override
  Future<List<Bus>> searchBuses(
      {required String boardingStop, required String destination}) async {
    final availableStops = await listStops();
    final from = _findStop(availableStops, boardingStop);
    final to = _findStop(availableStops, destination);
    if (from == null || to == null) {
      throw const BusRepositoryException(
          'Choose both stops from the backend stop suggestions.');
    }
    if (from.stopId == to.stopId) {
      throw const BusRepositoryException(
          'Boarding and destination stops must differ.');
    }
    final page = _asMap(await _client.getJson(
      'buses/search',
      queryParameters: {
        'fromStopId': from.stopId,
        'toStopId': to.stopId,
        'page': '0',
        'size': '100'
      },
    ));
    final content = page['content'];
    if (content is! List) {
      throw const FormatException(
          'The backend bus results have an invalid format.');
    }
    try {
      final buses = content
          .map((entry) => Bus.fromBackendJson(
                _asMap(entry),
                boardingStop: from.name,
                destination: to.name,
                boardingStopId: from.stopId,
                destinationStopId: to.stopId,
              ))
          .toList(growable: false);
      return await Future.wait(buses.map((bus) async {
        final requestedTripId = bus.dataOrigin == 'SIMULATED'
            ? simulatedTripIdForBus(bus.busId)
            : null;
        try {
          final occupancy = OccupancyData.fromJson(_asMap(await _client.getJson(
            'buses/${Uri.encodeComponent(bus.busId)}/occupancy',
            queryParameters: {
              'stopId': from.stopId,
              if (requestedTripId != null) 'tripId': requestedTripId,
            },
          )));
          final responseMatchesRequest = occupancy.busId == bus.busId &&
              occupancy.stopId == from.stopId &&
              (requestedTripId == null || occupancy.tripId == requestedTripId);
          final estimateIsScopedAndFresh = responseMatchesRequest &&
              occupancy.tripId != null &&
              (occupancy.freshnessStatus == 'FRESH' ||
                  occupancy.freshnessStatus == 'SIMULATED') &&
              (occupancy.occupancyStatus == 'CALCULATED' ||
                  occupancy.occupancyStatus == 'CALCULATED_WITH_WARNINGS');
          final responseHasTrip =
              responseMatchesRequest && occupancy.tripId != null;
          return bus.withOccupancy(
            passengers:
                estimateIsScopedAndFresh ? occupancy.onboardPassengers : null,
            availableSeats: estimateIsScopedAndFresh
                ? occupancy.provisionalAvailableSeats
                : null,
            freshness: occupancy.freshnessStatus,
            updatedAt: occupancy.dataUpdatedAt,
            category: estimateIsScopedAndFresh
                ? occupancy.crowdingCategory
                : 'UNKNOWN',
            selectedTripId: responseMatchesRequest
                ? occupancy.tripId ?? requestedTripId
                : requestedTripId,
            sourceOrigin: occupancy.dataOrigin,
            status: occupancy.occupancyStatus,
            reservedPassengers:
                responseHasTrip ? occupancy.confirmedReservedPassengers : null,
            remainingCapacity:
                responseHasTrip ? occupancy.remainingPassengerCapacity : null,
          );
        } on ApiClientException {
          return bus.withOccupancy(
              passengers: null,
              availableSeats: null,
              freshness: 'UNKNOWN',
              updatedAt: null,
              category: 'UNKNOWN',
              selectedTripId: requestedTripId,
              sourceOrigin: null,
              status: 'UNKNOWN',
              reservedPassengers: null,
              remainingCapacity: null);
        } on FormatException {
          return bus.withOccupancy(
              passengers: null,
              availableSeats: null,
              freshness: 'UNKNOWN',
              updatedAt: null,
              category: 'UNKNOWN',
              selectedTripId: requestedTripId,
              sourceOrigin: null,
              status: 'UNKNOWN',
              reservedPassengers: null,
              remainingCapacity: null);
        } on TypeError {
          return bus.withOccupancy(
              passengers: null,
              availableSeats: null,
              freshness: 'UNKNOWN',
              updatedAt: null,
              category: 'UNKNOWN',
              selectedTripId: requestedTripId,
              sourceOrigin: null,
              status: 'UNKNOWN',
              reservedPassengers: null,
              remainingCapacity: null);
        }
      }));
    } on FormatException {
      throw const BusRepositoryException(
          'The backend returned bus data that this app cannot display.');
    }
  }

  @override
  Future<BusDetailsData> loadDetails(Bus bus) async {
    if (bus.routeId == null ||
        bus.boardingStopId == null ||
        bus.destinationStopId == null) {
      throw const BusRepositoryException(
          'This bus result is missing route or selected-stop identifiers.');
    }

    final responses = await Future.wait<Object?>([
      _client.getJson('buses/${Uri.encodeComponent(bus.busId)}'),
      _client.getJson('routes/${Uri.encodeComponent(bus.routeId!)}/stops'),
      _client.getJson(
        'buses/${Uri.encodeComponent(bus.busId)}/occupancy',
        queryParameters: {
          'stopId': bus.boardingStopId!,
          if (bus.tripId != null) 'tripId': bus.tripId!,
        },
      ),
    ]);

    final detailsBus = Bus.fromBackendJson(
      _asMap(responses[0]),
      boardingStop: bus.boardingStop,
      destination: bus.destination,
      boardingStopId: bus.boardingStopId!,
      destinationStopId: bus.destinationStopId!,
    );
    if (detailsBus.routeId != bus.routeId) {
      throw const BusRepositoryException(
          'The bus route changed after search. Search again to refresh results.');
    }
    final routeResponse = responses[1];
    if (routeResponse is! List) {
      throw const BusRepositoryException(
          'The route stops response is invalid.');
    }
    final orderedStops = routeResponse
        .map((entry) => StopOption.fromJson(_asMap(entry)))
        .toList(growable: false);
    final occupancy = OccupancyData.fromJson(_asMap(responses[2]));

    BusLocationData? location;
    String? locationMessage;
    try {
      location = BusLocationData.fromJson(
        _asMap(await _client
            .getJson('buses/${Uri.encodeComponent(bus.busId)}/location')),
      );
    } on ApiClientException catch (error) {
      locationMessage = error.statusCode == 404
          ? 'No location has been recorded.'
          : 'Location could not be loaded.';
    } on FormatException {
      locationMessage = 'Location data was incomplete.';
    }

    return BusDetailsData(
      bus: detailsBus,
      orderedStops: orderedStops,
      occupancy: occupancy,
      location: location,
      locationMessage: locationMessage,
    );
  }

  static StopOption? _findStop(List<StopOption> stops, String name) {
    final normalized = name.trim().toLowerCase();
    for (final stop in stops) {
      if (stop.name.trim().toLowerCase() == normalized ||
          stop.stopId.trim().toLowerCase() == normalized) {
        return stop;
      }
    }
    return null;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw const FormatException(
        'The backend response has an invalid JSON shape.');
  }

  @override
  void close() => _client.close();
}
