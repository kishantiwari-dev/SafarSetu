import '../../models/backend_data.dart';

String? validateSimulatedTripId(String? value) =>
    value == null || value.trim().isEmpty
        ? 'Enter a simulated trip identifier.'
        : value.trim().length > 64
            ? 'Trip identifiers must be 64 characters or fewer.'
            : null;

String? validateSimulatedPassengerCount(String? value) {
  final count = int.tryParse(value?.trim() ?? '');
  return count == null || count <= 0 ? 'Enter a positive whole number.' : null;
}

bool validSimulatedJourney(
    List<StopOption> stops, String? boardingStopId, String? destinationStopId) {
  if (boardingStopId == null || destinationStopId == null) return false;
  final from = stops.indexWhere((stop) => stop.stopId == boardingStopId);
  final to = stops.indexWhere((stop) => stop.stopId == destinationStopId);
  return from >= 0 && to > from;
}
