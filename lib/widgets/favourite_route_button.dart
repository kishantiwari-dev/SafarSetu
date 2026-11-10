import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/local_demo_store.dart';
import '../models/bus.dart';

class FavouriteRouteButton extends StatefulWidget {
  const FavouriteRouteButton({super.key, required this.bus});
  final Bus bus;

  @override
  State<FavouriteRouteButton> createState() => _FavouriteRouteButtonState();
}

class _FavouriteRouteButtonState extends State<FavouriteRouteButton> {
  final _store = LocalDemoStore();
  bool? _saved;
  bool _saving = false;

  SavedRoute get _route => SavedRoute(
        fromStopId: widget.bus.boardingStopId ??
            'mock:${widget.bus.boardingStop.trim().toLowerCase()}',
        fromName: widget.bus.boardingStop,
        toStopId: widget.bus.destinationStopId ??
            'mock:${widget.bus.destination.trim().toLowerCase()}',
        toName: widget.bus.destination,
        routeId: widget.bus.routeId,
        busId: widget.bus.busId,
      );

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final value = await _isSaved();
      if (mounted) setState(() => _saved = value);
    } catch (_) {
      if (mounted) setState(() => _saved = false);
    }
  }

  Future<bool> _isSaved() async =>
      (await _store.loadFavourites()).any((r) => r.key == _route.key);

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip:
            _saved == true ? 'Remove favourite route' : 'Save favourite route',
        onPressed: _saved == null || _saving ? null : _toggle,
        icon: Icon(_saved == true ? Icons.favorite : Icons.favorite_border,
            color: _saved == true ? AppColors.accent : AppColors.secondaryText),
      );

  Future<void> _toggle() async {
    final previous = _saved!;
    final next = !previous;
    setState(() {
      _saved = next;
      _saving = true;
    });
    try {
      await _store.setFavourite(_route, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next
              ? 'Route saved on this device.'
              : 'Route removed from favourites.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saved = previous);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update favourites. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
