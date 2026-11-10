import 'package:flutter_test/flutter_test.dart';
import 'package:safarsetu/models/backend_data.dart';
import 'package:safarsetu/screens/etm/etm_validation.dart';

void main() {
  const stops = [
    StopOption(stopId: 'a', name: 'A', stopOrder: 0),
    StopOption(stopId: 'b', name: 'B', stopOrder: 1),
    StopOption(stopId: 'c', name: 'C', stopOrder: 2),
  ];

  test('requires a positive whole passenger count', () {
    expect(validateSimulatedPassengerCount('1'), isNull);
    expect(validateSimulatedPassengerCount('0'), isNotNull);
    expect(validateSimulatedPassengerCount('-2'), isNotNull);
    expect(validateSimulatedPassengerCount('1.5'), isNotNull);
    expect(validateSimulatedPassengerCount('abc'), isNotNull);
  });

  test('requires journey destination to follow boarding in route order', () {
    expect(validSimulatedJourney(stops, 'a', 'b'), isTrue);
    expect(validSimulatedJourney(stops, 'a', 'c'), isTrue);
    expect(validSimulatedJourney(stops, 'b', 'b'), isFalse);
    expect(validSimulatedJourney(stops, 'c', 'a'), isFalse);
    expect(validSimulatedJourney(stops, null, 'b'), isFalse);
  });

  test('requires a bounded simulated trip identifier', () {
    expect(validateSimulatedTripId('SIM-TRIP-1'), isNull);
    expect(validateSimulatedTripId('  '), isNotNull);
    expect(validateSimulatedTripId(List<String>.filled(65, 'x').join()),
        isNotNull);
  });
}
