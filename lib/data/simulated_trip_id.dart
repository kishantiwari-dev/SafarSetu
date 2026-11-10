/// Returns the default simulated trip identifier used by the ETM for a bus.
///
/// Keeping this convention shared lets passenger occupancy lookups stay scoped
/// to the same daily trip used by the conductor workflow.
String simulatedTripIdForBus(String busId, {DateTime? now}) {
  final day = (now ?? DateTime.now())
      .toUtc()
      .toIso8601String()
      .substring(0, 10)
      .replaceAll('-', '');
  final id = busId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'SIM-$id-$day';
}
