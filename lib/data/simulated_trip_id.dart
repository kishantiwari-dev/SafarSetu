/// Returns the backend's stable trip identifier for a simulated demo bus.
///
/// The backend seed data and ETM validation share this convention. Keeping it
/// aligned ensures bus search reads the same tickets used by the ETM workflow.
String simulatedTripIdForBus(String busId) {
  final id = busId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'SIM-TRIP-$id-DEMO-01';
}
