import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/bus.dart';

class OccupancyIndicator extends StatelessWidget {
  const OccupancyIndicator({
    super.key,
    required this.bus,
    this.occupancyOverride,
    this.capacityOverride,
    this.freshnessStatus,
  });

  final Bus bus;
  final int? occupancyOverride;
  final int? capacityOverride;
  final String? freshnessStatus;

  @override
  Widget build(BuildContext context) {
    final occupancy = occupancyOverride ?? bus.safePredictedOccupancy;
    final capacity = capacityOverride ?? bus.capacity;
    final freshness = freshnessStatus ?? bus.occupancyFreshness;
    if (occupancy == null ||
        capacity <= 0 ||
        (bus.source == BusDataSource.backend &&
            freshness != 'FRESH' &&
            freshness != 'SIMULATED')) {
      return const Text('Occupancy estimate unavailable',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12));
    }
    if (occupancy < 0 || occupancy > (bus.totalPassengerCapacity ?? capacity)) {
      return const Text('Invalid occupancy data · estimate withheld',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12));
    }
    final percent = (occupancy * 100 / capacity).round();
    final seatsLeft = (100 - percent).clamp(0, 100);
    final level = percent < CrowdingThresholds.moderate
        ? CrowdLevel.low
        : percent < CrowdingThresholds.crowded
            ? CrowdLevel.moderate
            : percent < CrowdingThresholds.overcrowded
                ? CrowdLevel.high
                : CrowdLevel.veryHigh;
    final color = switch (level) {
      CrowdLevel.low => AppColors.accent,
      CrowdLevel.moderate => AppColors.accentBlue,
      CrowdLevel.high => const Color(0xFF6F9FC2),
      CrowdLevel.veryHigh => const Color(0xFFFF7B72),
      CrowdLevel.unknown => AppColors.secondaryText,
    };
    final crowdLabel = switch (level) {
      CrowdLevel.low => 'Normal',
      CrowdLevel.moderate => 'Moderately crowded',
      CrowdLevel.high => 'Crowded',
      CrowdLevel.veryHigh => 'Overcrowded',
      CrowdLevel.unknown => 'Occupancy unavailable',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
        const SizedBox(height: 7),
        Text('$seatsLeft% seats left · $percent% occupied · $crowdLabel',
            style:
                const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        if (level == CrowdLevel.veryHigh) ...[
          const SizedBox(height: 5),
          const Text('Very limited seats likely available.',
              style: TextStyle(color: Color(0xFFFF7B72), fontSize: 11)),
        ],
      ],
    );
  }
}
