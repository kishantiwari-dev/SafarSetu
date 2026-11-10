import '../models/backend_data.dart';
import '../models/bus.dart';

abstract interface class BusRepository {
  bool get isApiBacked;

  Future<List<StopOption>> listStops();

  Future<List<Bus>> searchBuses({
    required String boardingStop,
    required String destination,
  });

  Future<BusDetailsData> loadDetails(Bus bus);

  void close();
}

class BusRepositoryException implements Exception {
  const BusRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
