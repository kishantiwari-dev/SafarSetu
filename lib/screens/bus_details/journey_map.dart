import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local_demo_store.dart';
import '../../models/backend_data.dart';
import '../../models/bus.dart';

class JourneyMap extends StatefulWidget {
  const JourneyMap({super.key, required this.details});

  final BusDetailsData details;

  @override
  State<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends State<JourneyMap> {
  bool _tilesFailed = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final routeStops = _journeyStops(details);
    final locatedStops = routeStops.where(_hasCoordinates).toList();
    final points = locatedStops
        .map((stop) => LatLng(stop.latitude!, stop.longitude!))
        .toList();
    final hasBusPoint = details.location != null &&
        _validCoordinate(
            details.location!.latitude, details.location!.longitude);
    if (points.isEmpty && !hasBusPoint) {
      return _empty('Map coordinates are unavailable for this journey.');
    }

    final allVerified = locatedStops.isNotEmpty &&
        locatedStops.every(
          (stop) => (stop.verificationStatus ?? '').toUpperCase() == 'VERIFIED',
        );
    final center = points.isNotEmpty
        ? points[points.length ~/ 2]
        : LatLng(details.location!.latitude, details.location!.longitude);
    final markers = <Marker>[
      for (var i = 0; i < locatedStops.length; i++)
        Marker(
          point: points[i],
          width: 40,
          height: 48,
          child: Tooltip(
            message:
                '${locatedStops[i].name} · ${locatedStops[i].verificationStatus ?? 'UNVERIFIED'} coordinates',
            child: Icon(
              i == 0
                  ? Icons.trip_origin_rounded
                  : i == locatedStops.length - 1
                      ? Icons.location_on_rounded
                      : Icons.circle,
              color: i == 0 ? AppColors.accent : AppColors.accentBlue,
              size: i > 0 && i < locatedStops.length - 1 ? 15 : 30,
            ),
          ),
        ),
      if (hasBusPoint)
        Marker(
          point:
              LatLng(details.location!.latitude, details.location!.longitude),
          width: 44,
          height: 44,
          child: Tooltip(
            message: details.location!.dataOrigin == 'SIMULATED'
                ? 'Simulated bus location'
                : 'Recorded bus location · ${details.location!.dataOrigin}',
            child: const Icon(Icons.directions_bus_filled,
                color: Colors.deepOrange, size: 30),
          ),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 270,
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 11),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'in.safarsetu.app',
                  errorTileCallback: (_, __, ___) {
                    if (mounted && !_tilesFailed) {
                      setState(() => _tilesFailed = true);
                    }
                  },
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors')
                  ],
                ),
                if (points.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(
                        points: points,
                        strokeWidth: 4,
                        color: AppColors.accent),
                  ]),
                MarkerLayer(markers: markers),
              ],
            ),
            if (_tilesFailed)
              const Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Padding(
                    padding: EdgeInsets.all(9),
                    child: Text(
                        'Map tiles unavailable. Journey markers may still appear.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.primaryText, fontSize: 11)),
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'Boarding: ${details.bus.boardingStop} · Destination: ${details.bus.destination}',
        style: const TextStyle(color: AppColors.primaryText, fontSize: 11),
      ),
      const SizedBox(height: 4),
      Text(
        locatedStops.isEmpty
            ? 'Route stops have no usable coordinates.'
            : allVerified
                ? 'Route line uses verified stop coordinates.'
                : 'Schematic route · stop coordinates are approximate or unverified.',
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
      ),
      if (details.location != null) ...[
        const SizedBox(height: 3),
        Text(
          '${details.location!.dataOrigin == 'SIMULATED' ? 'Simulated' : 'Recorded'} bus location · ${details.location!.freshnessStatus}${details.location!.stale ? ' · stale timestamp' : ''} · recorded ${details.location!.recordedAt.toLocal()}',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
        ),
      ] else if (details.locationMessage != null) ...[
        const SizedBox(height: 3),
        Text(details.locationMessage!,
            style:
                const TextStyle(color: AppColors.secondaryText, fontSize: 10)),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _openGoogleMaps(context),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Open in Google Maps'),
        ),
      ),
    ]);
  }

  List<StopOption> _journeyStops(BusDetailsData details) {
    final stops = details.orderedStops;
    final from =
        stops.indexWhere((s) => s.stopId == details.bus.boardingStopId);
    final to =
        stops.indexWhere((s) => s.stopId == details.bus.destinationStopId);
    if (from >= 0 && to > from) return stops.sublist(from, to + 1);
    if (details.bus.source == BusDataSource.mock) return stops;
    return const [];
  }

  bool _hasCoordinates(StopOption stop) =>
      stop.latitude != null &&
      stop.longitude != null &&
      _validCoordinate(stop.latitude!, stop.longitude!);

  bool _validCoordinate(double lat, double lon) =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;

  Widget _empty(String message) => Container(
        height: 205,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, color: AppColors.secondaryText),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryText)),
          const SizedBox(height: 10),
          Text(
              '${widget.details.bus.boardingStop} → ${widget.details.bus.destination}',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.primaryText, fontSize: 12)),
          TextButton.icon(
            onPressed: () => _openGoogleMaps(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Open journey in Google Maps'),
          ),
        ]),
      );

  Future<void> _openGoogleMaps(BuildContext context) async {
    final transitMode = await LocalDemoStore().loadTransitModeEnabled();
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': widget.details.bus.boardingStop,
      'destination': widget.details.bus.destination,
      'travelmode': transitMode ? 'transit' : 'driving',
    });
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')));
    }
  }
}
