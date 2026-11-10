import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local_demo_store.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.onOpenJourney});
  final ValueChanged<RecentJourney> onOpenJourney;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _store = LocalDemoStore();
  late Future<List<RecentJourney>> _journeys;

  @override
  void initState() {
    super.initState();
    _journeys = _store.loadRecentJourneys();
  }

  void _reload() => setState(() => _journeys = _store.loadRecentJourneys());

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            title: Text('Recent journeys',
                style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 19,
                    fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<List<RecentJourney>>(
                future: _journeys,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load recent journeys.',
                            style: TextStyle(color: AppColors.secondaryText)),
                        TextButton(
                            onPressed: _reload, child: const Text('Retry')),
                      ],
                    );
                  }
                  final journeys = snapshot.data ?? const <RecentJourney>[];
                  if (journeys.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                          'No recent journeys yet. Search for a route and it will appear here.',
                          style: TextStyle(color: AppColors.secondaryText)),
                    );
                  }
                  return Column(
                    children: [
                      for (final journey in journeys)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.history_rounded,
                                color: AppColors.accent),
                            title: Text(
                                '${journey.fromName} → ${journey.toName}',
                                style: const TextStyle(
                                    color: AppColors.primaryText)),
                            subtitle: Text(
                              'Saved search${journey.searchedAt == null ? '' : ' · ${journey.searchedAt!.toLocal()}'}',
                              style: const TextStyle(
                                  color: AppColors.secondaryText, fontSize: 11),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color: AppColors.secondaryText),
                            onTap: () => widget.onOpenJourney(journey),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      );
}
