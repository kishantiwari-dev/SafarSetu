import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedRoute {
  const SavedRoute({
    required this.fromStopId,
    required this.fromName,
    required this.toStopId,
    required this.toName,
    this.routeId,
    this.busId,
  });

  final String fromStopId;
  final String fromName;
  final String toStopId;
  final String toName;
  final String? routeId;
  final String? busId;

  String get key => '$fromStopId::$toStopId::${routeId ?? ''}';

  Map<String, Object?> toJson() => {
        'fromStopId': fromStopId,
        'fromName': fromName,
        'toStopId': toStopId,
        'toName': toName,
        'routeId': routeId,
        'busId': busId,
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        fromStopId: json['fromStopId'] as String,
        fromName: json['fromName'] as String,
        toStopId: json['toStopId'] as String,
        toName: json['toName'] as String,
        routeId: json['routeId'] as String?,
        busId: json['busId'] as String?,
      );
}

class RecentJourney {
  const RecentJourney({
    required this.fromStopId,
    required this.fromName,
    required this.toStopId,
    required this.toName,
    this.routeId,
    this.tripId,
    this.searchedAt,
  });

  final String fromStopId;
  final String fromName;
  final String toStopId;
  final String toName;
  final String? routeId;
  final String? tripId;
  final DateTime? searchedAt;

  String get key => '$fromStopId::$toStopId';

  Map<String, Object?> toJson() => {
        'fromStopId': fromStopId,
        'fromName': fromName,
        'toStopId': toStopId,
        'toName': toName,
        'routeId': routeId,
        'tripId': tripId,
        'searchedAt': searchedAt?.toIso8601String(),
      };

  factory RecentJourney.fromJson(Map<String, dynamic> json) => RecentJourney(
        fromStopId: json['fromStopId'] as String,
        fromName: json['fromName'] as String,
        toStopId: json['toStopId'] as String,
        toName: json['toName'] as String,
        routeId: json['routeId'] as String?,
        tripId: json['tripId'] as String?,
        searchedAt: DateTime.tryParse(json['searchedAt'] as String? ?? ''),
      );
}

/// Local demo-user preferences. This is not an account or synchronized profile.
class LocalDemoStore {
  LocalDemoStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _favouritesKey = 'safarsetu.demo.favourites.v1';
  static const _recentKey = 'safarsetu.demo.recent.v1';
  static const _nameKey = 'safarsetu.demo.profile.name';
  static const _emailKey = 'safarsetu.demo.profile.email';
  final SharedPreferencesAsync _preferences;

  Future<List<SavedRoute>> loadFavourites() async {
    final encoded = await _preferences.getString(_favouritesKey);
    if (encoded == null) return const [];
    try {
      final value = jsonDecode(encoded);
      if (value is! List) return const [];
      final result = <SavedRoute>[];
      for (final item in value.whereType<Map<String, dynamic>>()) {
        try {
          final route = SavedRoute.fromJson(item);
          if (route.fromStopId.isNotEmpty &&
              route.toStopId.isNotEmpty &&
              route.fromStopId != route.toStopId &&
              !result.any((saved) => saved.key == route.key)) {
            result.add(route);
          }
        } on Object {
          // Discard invalid/obsolete local entries without affecting valid routes.
        }
      }
      return result;
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveFavourites(List<SavedRoute> routes) =>
      _preferences.setString(
          _favouritesKey, jsonEncode(routes.map((e) => e.toJson()).toList()));

  Future<void> setFavourite(SavedRoute route, bool saved) async {
    final routes = await loadFavourites();
    final updated = routes.where((item) => item.key != route.key).toList();
    if (saved) updated.add(route);
    await saveFavourites(updated);
  }

  Future<List<RecentJourney>> loadRecentJourneys() async {
    final encoded = await _preferences.getString(_recentKey);
    if (encoded == null) return const [];
    try {
      final value = jsonDecode(encoded);
      if (value is! List) return const [];
      final result = <RecentJourney>[];
      for (final item in value.whereType<Map<String, dynamic>>()) {
        try {
          final journey = RecentJourney.fromJson(item);
          if (journey.fromStopId.isNotEmpty &&
              journey.toStopId.isNotEmpty &&
              journey.fromStopId != journey.toStopId &&
              !result.any((e) => e.key == journey.key)) {
            result.add(journey);
          }
        } on Object {
          // Ignore malformed local entries.
        }
      }
      return result;
    } on FormatException {
      return const [];
    }
  }

  Future<void> recordJourney(RecentJourney journey) async {
    final all = await loadRecentJourneys();
    final updated =
        [journey, ...all.where((e) => e.key != journey.key)].take(20).toList();
    await _preferences.setString(
        _recentKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<String> loadName() async =>
      await _preferences.getString(_nameKey) ?? 'Passenger';

  Future<String?> loadEmail() => _preferences.getString(_emailKey);

  Future<void> saveProfile({required String name, String? email}) async {
    await _preferences.setString(_nameKey, name.trim());
    if (email != null && email.trim().isNotEmpty) {
      await _preferences.setString(_emailKey, email.trim());
    }
  }

  Future<bool> loadTransitModeEnabled() async =>
      await _preferences.getBool('safarsetu.demo.googleMapsTransitMode') ??
      true;

  Future<void> saveTransitModeEnabled(bool enabled) =>
      _preferences.setBool('safarsetu.demo.googleMapsTransitMode', enabled);
}
