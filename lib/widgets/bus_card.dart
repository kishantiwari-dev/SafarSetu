import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/bus.dart';
import 'occupancy_indicator.dart';
import 'favourite_route_button.dart';

class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.bus, required this.onTap});

  final Bus bus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(bus.busId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText)),
            ),
            if (bus.crowdLevel == CrowdLevel.veryHigh) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF7B72).withValues(alpha: .16),
                    border: Border.all(color: const Color(0xFFFF7B72)),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('OVERCROWDED',
                    style: TextStyle(
                        color: Color(0xFFFF9A91),
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
            const Spacer(),
            if (bus.etaMinutes != null) ...[
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Tooltip(
                message:
                    bus.etaAssumption ?? _etaUnavailableReason(bus.etaStatus),
                child: Text(
                  bus.etaMinutes == null
                      ? _etaUnavailableLabel(bus.etaStatus)
                      : '≈ ${bus.etaMinutes} min · ${bus.etaDataOrigin == 'SIMULATED' || bus.source == BusDataSource.mock ? 'simulated' : 'route estimate'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            FavouriteRouteButton(bus: bus),
          ]),
          const SizedBox(height: 13),
          Text(bus.route,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.secondaryText, height: 1.4)),
          const SizedBox(height: 4),
          Text('${bus.boardingStop} → ${bus.destination}',
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 12)),
          const SizedBox(height: 17),
          _OccupancyStat(
            label: 'PROVISIONAL SEATS AVAILABLE',
            value: bus.predictedSeatsLeftPercent == null
                ? 'Unavailable'
                : '${bus.predictedAvailableSeats} / ${bus.capacity} seats',
            detail: bus.predictedPercent == null
                ? 'Occupancy estimate unavailable'
                : '${bus.predictedPercent}% occupied · ${bus.predictedSeatsLeftPercent}% provisionally available · ${bus.crowdLabel}',
            emphasized: true,
          ),
          const SizedBox(height: 15),
          OccupancyIndicator(bus: bus),
          if (bus.source == BusDataSource.backend) ...[
            const SizedBox(height: 8),
            _CapacitySummary(bus: bus),
          ],
          if (bus.source == BusDataSource.mock ||
              bus.occupancyDataOrigin == 'SIMULATED') ...[
            const SizedBox(height: 5),
            const Text('Simulated estimate · not live data',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 10)),
          ],
          if (bus.tripId != null) ...[
            const SizedBox(height: 5),
            Text('Trip: ${bus.tripId}',
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 10)),
          ],
          const SizedBox(height: 10),
          if (bus.recommendation != null)
            Row(children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 15, color: AppColors.accentBlue),
              const SizedBox(width: 7),
              Expanded(
                child: Text(bus.recommendation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 11)),
              ),
            ]),
          const SizedBox(height: 13),
          Row(children: [
            const Icon(Icons.event_seat_outlined,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 7),
            Text(
                bus.predictedSeatsLeftPercent == null
                    ? 'Seat estimate unavailable'
                    : '${bus.predictedAvailableSeats} seats · ${bus.predictedSeatsLeftPercent}% provisionally available',
                style: const TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Details'),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ]),
            ),
          ]),
        ]),
      );
}

String _etaUnavailableLabel(String? status) => switch (status) {
      'NO_LOCATION' => 'ETA unavailable · no location',
      'STALE_LOCATION' => 'ETA unavailable · stale location',
      'DESTINATION_REACHED_OR_PASSED' => 'At/past destination',
      'API_ERROR' => 'ETA unavailable · API error',
      'ROUTE_COORDINATES_MISSING' => 'ETA unavailable · route data',
      _ => 'ETA unavailable',
    };

String _etaUnavailableReason(String? status) => switch (status) {
      'NO_LOCATION' => 'No bus location has been recorded.',
      'STALE_LOCATION' =>
        'The latest bus location is older than the allowed freshness window.',
      'DESTINATION_REACHED_OR_PASSED' =>
        'The latest location places the bus at or beyond the selected destination.',
      'API_ERROR' => 'The backend ETA request failed.',
      'ROUTE_COORDINATES_MISSING' =>
        'One or more route stops have no coordinates.',
      _ => 'ETA requires a recent location and route coordinates.',
    };

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket-derived onboard estimate: ${bus.predictedOccupancy ?? 'Unknown'}',
            style:
                const TextStyle(color: AppColors.secondaryText, fontSize: 11),
          ),
          Text(
            'Confirmed reservations: ${bus.confirmedReservedPassengers ?? 'Unknown'}',
            style:
                const TextStyle(color: AppColors.secondaryText, fontSize: 11),
          ),
          Text(
            'Passenger capacity remaining: ${bus.remainingPassengerCapacity ?? 'Unknown'}',
            style:
                const TextStyle(color: AppColors.secondaryText, fontSize: 11),
          ),
          if (const {
            'API_ERROR',
            'INVALID_RESPONSE',
            'TRIP_CONTEXT_REQUIRED',
            'NO_TICKET_DATA',
            'NO_TICKET_DATA_FOR_TRIP',
          }.contains(bus.occupancyStatus))
            Text(
              switch (bus.occupancyStatus) {
                'API_ERROR' => 'Occupancy API request failed.',
                'INVALID_RESPONSE' =>
                  'Occupancy response was incomplete or invalid.',
                'TRIP_CONTEXT_REQUIRED' =>
                  'A single trip must be selected to calculate occupancy.',
                'NO_TICKET_DATA' =>
                  'No ticket events are recorded; zero is not assumed.',
                _ => 'No ticket events are recorded for this trip.',
              },
              style:
                  const TextStyle(color: AppColors.secondaryText, fontSize: 10),
            ),
        ],
      );
}

class _OccupancyStat extends StatelessWidget {
  const _OccupancyStat({
    required this.label,
    required this.value,
    required this.detail,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: emphasized
              ? AppColors.accent.withValues(alpha: .08)
              : AppColors.background.withValues(alpha: .44),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasized
                ? AppColors.accent.withValues(alpha: .25)
                : AppColors.border.withValues(alpha: .65),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: .55,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color:
                        emphasized ? AppColors.accent : AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 3),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 10)),
        ]),
      );
}
