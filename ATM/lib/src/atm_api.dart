import 'dart:convert';

import 'package:http/http.dart' as http;

const atmApiBaseUrl = String.fromEnvironment(
  'SAFARSETU_API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

class AtmStop {
  const AtmStop({required this.id, required this.name, this.order});
  final String id;
  final String name;
  final int? order;

  factory AtmStop.fromJson(Map<String, dynamic> json) => AtmStop(
    id: _requiredText(json, 'stopId'),
    name: _requiredText(json, 'name'),
    order: json['stopOrder'] is int ? json['stopOrder'] as int : null,
  );
}

class AtmBus {
  const AtmBus({
    required this.id,
    required this.fleetCode,
    required this.routeId,
    required this.routeName,
    required this.capacity,
    required this.origin,
    required this.active,
  });
  final String id;
  final String fleetCode;
  final String routeId;
  final String routeName;
  final int? capacity;
  final String origin;
  final bool active;
  String get demoTripId => 'SIM-TRIP-$id-DEMO-01';

  factory AtmBus.fromJson(Map<String, dynamic> json) => AtmBus(
    id: _requiredText(json, 'busId'),
    fleetCode: _requiredText(json, 'fleetCode'),
    routeId: _requiredText(json, 'routeId'),
    routeName: _requiredText(json, 'routeName'),
    capacity: json['totalPassengerCapacity'] is int
        ? json['totalPassengerCapacity'] as int
        : null,
    origin: _requiredText(json, 'dataOrigin'),
    active: json['active'] == true,
  );
}

class AtmBookingReceipt {
  const AtmBookingReceipt({
    required this.reference,
    required this.busId,
    required this.tripId,
    required this.boardingStop,
    required this.destinationStop,
    required this.passengerCount,
    required this.status,
    required this.createdAt,
  });
  final String reference;
  final String busId;
  final String tripId;
  final String boardingStop;
  final String destinationStop;
  final int passengerCount;
  final String status;
  final DateTime createdAt;

  factory AtmBookingReceipt.fromJson(Map<String, dynamic> json) =>
      AtmBookingReceipt(
        reference: _requiredText(json, 'bookingReference'),
        busId: _requiredText(json, 'busId'),
        tripId: _requiredText(json, 'tripId'),
        boardingStop: _requiredText(json, 'boardingStopName'),
        destinationStop: _requiredText(json, 'destinationStopName'),
        passengerCount: _requiredPositiveInt(json, 'passengerCount'),
        status: _requiredText(json, 'bookingStatus'),
        createdAt: DateTime.parse(_requiredText(json, 'createdAt')),
      );
}

class AtmApiException implements Exception {
  const AtmApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AtmApi {
  AtmApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? atmApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<List<AtmStop>> loadStops() async {
    final json = await _get('/stops?page=0&size=100');
    return _content(json).map(AtmStop.fromJson).toList(growable: false);
  }

  Future<List<AtmBus>> searchBuses({
    required String fromStopId,
    required String toStopId,
  }) async {
    if (fromStopId == toStopId) {
      throw const AtmApiException('Choose two different stops.');
    }
    final query = Uri(
      queryParameters: {
        'fromStopId': fromStopId,
        'toStopId': toStopId,
        'page': '0',
        'size': '100',
      },
    ).query;
    final json = await _get('/buses/search?$query');
    return _content(json)
        .map(AtmBus.fromJson)
        .where((bus) => bus.active && bus.origin == 'SIMULATED')
        .toList(growable: false);
  }

  Future<AtmBookingReceipt> createBooking({
    required String idempotencyKey,
    required AtmBus bus,
    required AtmStop from,
    required AtmStop to,
    required int passengerCount,
  }) async {
    if (passengerCount < 1 || from.id == to.id) {
      throw const AtmApiException('Check the journey and passenger quantity.');
    }
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/atm/bookings'),
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode({
            'idempotencyKey': idempotencyKey,
            'tripId': bus.demoTripId,
            'busId': bus.id,
            'boardingStopId': from.id,
            'destinationStopId': to.id,
            'passengerCount': passengerCount,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final payload = _decode(response);
    if (response.statusCode != 201) {
      throw AtmApiException(_errorMessage(payload, response.statusCode));
    }
    try {
      return AtmBookingReceipt.fromJson(payload);
    } on FormatException {
      throw const AtmApiException('The booking response was not valid JSON.');
    } on StateError {
      throw const AtmApiException(
        'The booking response is missing required details.',
      );
    }
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl$path'))
        .timeout(const Duration(seconds: 12));
    final payload = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AtmApiException(_errorMessage(payload, response.statusCode));
    }
    return payload;
  }

  static List<Map<String, dynamic>> _content(Map<String, dynamic> json) {
    final content = json['content'];
    if (content is! List) {
      throw const AtmApiException(
        'The backend returned an unexpected list response.',
      );
    }
    if (content.any((entry) => entry is! Map<String, dynamic>)) {
      throw const AtmApiException('The backend list contains an invalid item.');
    }
    return content.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
      throw const FormatException();
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AtmApiException(
          'Backend request failed (${response.statusCode}).',
        );
      }
      throw const AtmApiException(
        'The backend returned an unexpected response.',
      );
    }
  }

  static String _errorMessage(Map<String, dynamic> payload, int status) {
    final message = payload['message'];
    return message is String && message.isNotEmpty
        ? message
        : 'Backend request failed ($status).';
  }
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw StateError('Missing $key');
  }
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) {
    throw StateError('Invalid $key');
  }
  return value;
}
