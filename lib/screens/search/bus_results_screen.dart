import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/bus.dart';
import '../../data/bus_repository.dart';
import '../../widgets/bus_card.dart';
import '../bus_details/bus_details_screen.dart';

class BusResultsScreen extends StatefulWidget {
  const BusResultsScreen({
    super.key,
    required this.boardingStop,
    required this.destination,
    required this.buses,
    required this.repository,
  });

  final String boardingStop;
  final String destination;
  final List<Bus> buses;
  final BusRepository repository;

  @override
  State<BusResultsScreen> createState() => _BusResultsScreenState();
}

class _BusResultsScreenState extends State<BusResultsScreen> {
  int _favouriteRefresh = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Bus options',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Text('Buses for your journey',
                  style: TextStyle(
                      fontSize: 24,
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text('${widget.boardingStop} → ${widget.destination}',
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 14)),
              const SizedBox(height: 10),
              _dataNotice(),
              const SizedBox(height: 20),
              if (widget.buses.isEmpty)
                _emptyState(context)
              else ...[
                Text('${widget.buses.length} buses found',
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 11),
                for (final bus in widget.buses) ...[
                  BusCard(
                    key: ValueKey('$_favouriteRefresh-${bus.busId}'),
                    bus: bus,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => BusDetailsScreen(
                            bus: bus,
                            repository: widget.repository,
                            comparisonBuses: widget.buses),
                      ));
                      if (mounted) setState(() => _favouriteRefresh++);
                    },
                  ),
                  const SizedBox(height: 13),
                ],
              ],
            ],
          ),
        ),
      );

  Widget _dataNotice() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.accentBlue.withValues(alpha: .18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              size: 17, color: AppColors.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.repository.isApiBacked
                  ? 'Demo backend records and ETM events are simulated, not live data. Occupancy is loaded separately and may be unknown.'
                  : 'Simulated seat estimates for preview only, not live GPS or ETM data. Occupancy is estimated for your boarding stop.',
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 11, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _emptyState(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.directions_bus_outlined,
              size: 38, color: AppColors.secondaryText),
          const SizedBox(height: 14),
          const Text('No buses found for this route.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Try another destination or boarding point.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Search Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
          ),
        ]),
      );
}
