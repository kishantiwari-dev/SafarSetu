import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local_demo_store.dart';

class FavouriteRoutesScreen extends StatefulWidget {
  const FavouriteRoutesScreen({super.key, required this.onOpenRoute});
  final ValueChanged<SavedRoute> onOpenRoute;

  @override
  State<FavouriteRoutesScreen> createState() => _FavouriteRoutesScreenState();
}

class _FavouriteRoutesScreenState extends State<FavouriteRoutesScreen> {
  final _store = LocalDemoStore();
  late Future<List<SavedRoute>> _routes;

  @override
  void initState() {
    super.initState();
    _routes = _store.loadFavourites();
  }

  Future<void> _reload() async =>
      setState(() => _routes = _store.loadFavourites());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SavedRoute>>(
        future: _routes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load favourites.',
                  style: TextStyle(color: AppColors.primaryText)),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ]));
          }
          final routes = snapshot.data ?? const <SavedRoute>[];
          if (routes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 40, color: AppColors.secondaryText),
                  SizedBox(height: 12),
                  Text('No favourite routes yet',
                      style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                      'Search for a journey and tap the heart to save it on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondaryText)),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text('FAVOURITE ROUTES · LOCAL DEMO',
                  style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final route in routes)
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: const Icon(Icons.route_rounded,
                        color: AppColors.accent),
                    title: Text('${route.fromName} → ${route.toName}',
                        style: const TextStyle(color: AppColors.primaryText)),
                    subtitle: Text(
                        [
                          if (route.routeId != null) route.routeId!,
                          if (route.busId != null) route.busId!,
                          'Simulated route reference'
                        ].join(' · '),
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 11)),
                    onTap: () => widget.onOpenRoute(route),
                    trailing: IconButton(
                      tooltip: 'Remove favourite route',
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.secondaryText),
                      onPressed: () async {
                        setState(() => _routes = Future.value(routes
                            .where((item) => item.key != route.key)
                            .toList()));
                        try {
                          await _store.setFavourite(route, false);
                        } catch (_) {
                          await _reload();
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
