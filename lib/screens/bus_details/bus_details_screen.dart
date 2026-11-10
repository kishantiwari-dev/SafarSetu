import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/bus_repository.dart';
import '../../models/backend_data.dart';
import '../../models/bus.dart';
import '../../models/crowding_advisor.dart';
import '../../widgets/occupancy_indicator.dart';
import '../../widgets/favourite_route_button.dart';
import 'journey_map.dart';

class BusDetailsScreen extends StatefulWidget {
  const BusDetailsScreen(
      {super.key,
      required this.bus,
      required this.repository,
      this.comparisonBuses = const []});

  final Bus bus;
  final BusRepository repository;
  final List<Bus> comparisonBuses;

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  late Future<BusDetailsData> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.repository.loadDetails(widget.bus);
  }

  void _retry() => setState(() {
        _detailsFuture = widget.repository.loadDetails(widget.bus);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Bus details',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          actions: [FavouriteRouteButton(bus: widget.bus)],
        ),
        body: FutureBuilder<BusDetailsData>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_outlined,
                        color: AppColors.secondaryText, size: 32),
                    const SizedBox(height: 12),
                    Text(_errorMessage(snapshot.error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.primaryText)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ]),
                ),
              );
            }
            return _detailsView(snapshot.data!);
          },
        ),
      );

  String _errorMessage(Object? error) => error is BusRepositoryException
      ? error.message
      : error is FormatException
          ? 'The backend returned bus details this app could not read.'
          : 'Could not load bus details. Check the connection and retry.';

  Widget _detailsView(BusDetailsData details) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(children: [
            Text(details.bus.busId,
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (details.bus.etaMinutes != null) _etaBadge(details.bus),
          ]),
          const SizedBox(height: 7),
          Text(details.bus.route,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 14)),
          const SizedBox(height: 19),
          JourneyMap(details: details),
          const SizedBox(height: 18),
          _predictionCard(details),
          _crowdingAlternatives(details),
          const SizedBox(height: 15),
          _currentOccupancyCard(details),
          const SizedBox(height: 15),
          _stopsCard(details),
          const SizedBox(height: 12),
          Center(
            child: Text(
              details.bus.source == BusDataSource.backend
                  ? 'Backend data · ${details.bus.dataOrigin ?? 'SOURCE UNKNOWN'}'
                  : 'Mock data · Not a live prediction',
              style:
                  const TextStyle(color: AppColors.secondaryText, fontSize: 11),
            ),
          ),
        ],
      );

  Widget _etaBadge(Bus bus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text('${bus.etaMinutes} min',
              style: const TextStyle(
                  color: AppColors.primaryText, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _predictionCard(BusDetailsData details) {
    final bus = details.bus;
    final occupancy = details.occupancy;
    final isApi = bus.source == BusDataSource.backend;
    final rawPassengers =
        occupancy?.onboardPassengers ?? bus.predictedOccupancy;
    final passengerLimit = isApi
        ? occupancy?.totalPassengerCapacity ?? bus.totalPassengerCapacity
        : bus.totalPassengerCapacity ?? bus.capacity;
    final occupancyUsable = !isApi ||
        occupancy?.freshnessStatus == 'FRESH' ||
        occupancy?.freshnessStatus == 'SIMULATED';
    final seatingCapacityMatches = !isApi ||
        occupancy?.seatingCapacity == null ||
        occupancy!.seatingCapacity == bus.capacity;
    final passengers = occupancyUsable &&
            rawPassengers != null &&
            rawPassengers >= 0 &&
            (passengerLimit == null || rawPassengers <= passengerLimit) &&
            seatingCapacityMatches
        ? rawPassengers
        : null;
    final rawAvailableSeats =
        occupancy?.provisionalAvailableSeats ?? bus.predictedAvailableSeats;
    final availableSeats = passengers != null &&
            seatingCapacityMatches &&
            rawAvailableSeats != null &&
            rawAvailableSeats >= 0 &&
            rawAvailableSeats <= bus.capacity &&
            rawAvailableSeats ==
                (bus.capacity - passengers).clamp(0, bus.capacity)
        ? rawAvailableSeats
        : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: .13),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.accent.withValues(alpha: .42)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            isApi
                ? 'ESTIMATED AFTER YOUR BOARDING STOP'
                : 'PREDICTED AT YOUR STOP',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(passengers?.toString() ?? 'Unknown',
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w700)),
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 4),
            child: Text('/ ${bus.capacity} seats',
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 12),
        OccupancyIndicator(
          bus: bus,
          occupancyOverride: passengers,
          capacityOverride: isApi ? occupancy?.seatingCapacity : bus.capacity,
          freshnessStatus: isApi ? occupancy?.freshnessStatus : null,
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.event_seat_rounded,
              size: 21, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                availableSeats == null
                    ? 'Provisional seat estimate unavailable'
                    : isApi
                        ? 'About $availableSeats seats provisionally available'
                        : '$availableSeats seats expected available',
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          isApi
              ? 'Source: ${occupancy?.dataOrigin ?? bus.dataOrigin ?? 'BACKEND'} · freshness ${occupancy?.freshnessStatus ?? 'UNKNOWN'} · updated ${occupancy?.dataUpdatedAt?.toLocal() ?? 'time unavailable'}'
              : 'Source: simulated mock scenario · not live data',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
        ),
        if (isApi && occupancy?.tripId != null) ...[
          const SizedBox(height: 5),
          Text('Trip context: ${occupancy!.tripId}',
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 10)),
        ],
        const SizedBox(height: 8),
        if (isApi) ...[
          Text(
              occupancy?.seatEstimateAssumption ??
                  'One passenger per seat; actual seated passengers are not recorded.',
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 11)),
          const SizedBox(height: 5),
          const Text('Actual seated count: unavailable',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          for (final warning
              in occupancy?.dataQualityWarnings ?? const <String>[])
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(warning,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 10)),
            ),
        ] else
          Text(_comfortLabel(bus.crowdLevel),
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 12)),
      ]),
    );
  }

  Widget _crowdingAlternatives(BusDetailsData details) {
    final occupancy = details.occupancy;
    final warningApplies = details.bus.source == BusDataSource.backend
        ? CrowdingAdvisor.shouldWarn(occupancy)
        : details.bus.crowdLevel == CrowdLevel.veryHigh;
    if (!warningApplies) return const SizedBox.shrink();
    final alternatives =
        CrowdingAdvisor.alternatives(details.bus, widget.comparisonBuses);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: .25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overcrowding estimate',
            style: TextStyle(
                color: AppColors.primaryText, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text(
            'Very limited seats likely available. Consider a less crowded bus on this same journey.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        if (alternatives.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'No lower-crowding alternative has sufficiently fresh data.',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 12)))
        else
          for (final alternative in alternatives.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${alternative.busId} · ${alternative.predictedSeatsLeftPercent ?? '—'}% seats left · ${alternative.crowdLabel}',
                  style: const TextStyle(
                      color: AppColors.primaryText, fontSize: 12)),
            ),
      ]),
    );
  }

  Widget _currentOccupancyCard(BusDetailsData details) {
    final isApi = details.bus.source == BusDataSource.backend;
    final rawPassengers = isApi
        ? details.occupancy?.onboardPassengers
        : details.bus.safeCurrentOccupancy;
    final passengerLimit = details.occupancy?.totalPassengerCapacity ??
        details.bus.totalPassengerCapacity;
    final passengers = rawPassengers != null &&
            (details.bus.source != BusDataSource.backend ||
                details.occupancy?.freshnessStatus == 'FRESH' ||
                details.occupancy?.freshnessStatus == 'SIMULATED') &&
            rawPassengers >= 0 &&
            (passengerLimit == null || rawPassengers <= passengerLimit)
        ? rawPassengers
        : null;
    Widget detailRow(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Text(value,
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: isApi
          ? Column(children: [
              detailRow(
                  'Ticket-derived onboard estimate',
                  passengers == null
                      ? 'Unknown'
                      : '$passengers / ${details.occupancy?.totalPassengerCapacity ?? '—'}'),
              detailRow(
                  'Confirmed reserved passengers',
                  details.occupancy?.confirmedReservedPassengers?.toString() ??
                      'Unknown'),
              detailRow(
                  'Passenger capacity remaining',
                  details.occupancy?.remainingPassengerCapacity?.toString() ??
                      'Unknown'),
            ])
          : Row(children: [
              const Icon(Icons.people_alt_outlined,
                  color: AppColors.secondaryText, size: 21),
              const SizedBox(width: 11),
              const Expanded(
                child: Text('Current occupancy',
                    style: TextStyle(
                        color: AppColors.secondaryText, fontSize: 13)),
              ),
              Text(
                  passengers == null
                      ? 'Unknown'
                      : '$passengers / ${details.bus.capacity}',
                  style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
    );
  }

  Widget _stopsCard(BusDetailsData details) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR JOURNEY',
              style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _stopRow(Icons.trip_origin_rounded, details.bus.boardingStop,
              'Boarding point', AppColors.accent),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(height: 17, width: 1, color: AppColors.border),
          ),
          _stopRow(Icons.location_on_rounded, details.bus.destination,
              'Destination', AppColors.accentBlue),
          if (details.orderedStops.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('ROUTE STOPS',
                style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    letterSpacing: .9,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final stop in details.orderedStops)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                    '${stop.stopOrder ?? '•'}  ${stop.name} · ${stop.verificationStatus ?? 'UNKNOWN'}',
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 11)),
              ),
          ],
        ]),
      );

  Widget _stopRow(IconData icon, String title, String label, Color color) =>
      Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 10)),
              const SizedBox(height: 2),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );

  String _comfortLabel(CrowdLevel level) => switch (level) {
        CrowdLevel.low => 'Expected to be comfortable',
        CrowdLevel.moderate => 'Expected to be moderately busy',
        CrowdLevel.high => 'Expected to be crowded',
        CrowdLevel.veryHigh => 'Overcrowded estimate',
        CrowdLevel.unknown => 'Occupancy unavailable',
      };
}
