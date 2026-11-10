import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/mock_bus_repository.dart';
import '../../data/bus_repository.dart';
import '../../data/bus_repository_factory.dart';
import '../../data/local_demo_store.dart';
import '../../models/bus.dart';
import '../../models/backend_data.dart';
import '../../widgets/bus_card.dart';
import '../bus_details/bus_details_screen.dart';
import '../search/bus_results_screen.dart';
import '../trips/trips_screen.dart';
import '../trips/favourite_routes_screen.dart';
import '../etm/etm_simulation_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.demoEmail});
  final String? demoEmail;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController(text: 'Knowledge Park II');
  final _toController = TextEditingController(text: 'Pari Chowk');
  late final BusRepository _repository;
  final _localStore = LocalDemoStore();
  List<StopOption> _availableStops = const [];
  List<RecentJourney> _recentJourneys = const [];
  int _selectedTab = 0;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _repository = createBusRepository();
    unawaited(_loadStops());
    unawaited(_loadRecentJourneys());
  }

  Future<void> _loadRecentJourneys() async {
    try {
      final journeys = await _localStore.loadRecentJourneys();
      if (mounted) setState(() => _recentJourneys = journeys);
    } catch (_) {
      /* Keep the home screen usable if local storage is unavailable. */
    }
  }

  Future<void> _loadStops() async {
    try {
      final stops = await _repository.listStops();
      if (mounted) setState(() => _availableStops = stops);
    } catch (_) {
      // Search retries stop loading and reports a user-facing error if the API is unavailable.
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _repository.close();
    super.dispose();
  }

  Future<void> _searchBuses({bool validateForm = true}) async {
    FocusScope.of(context).unfocus();
    if (validateForm && _formKey.currentState?.validate() != true) return;
    setState(() => _searching = true);
    try {
      var resultsRepository = _repository;
      List<Bus> buses;
      try {
        buses = await _repository.searchBuses(
          boardingStop: _fromController.text,
          destination: _toController.text,
        );
      } on ApiClientException {
        if (!_repository.isApiBacked) rethrow;
        resultsRepository = const MockBusRepository();
        buses = await resultsRepository.searchBuses(
          boardingStop: _fromController.text,
          destination: _toController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Backend unavailable. Showing simulated sample data.'),
          ));
        }
      } on BusRepositoryException {
        if (!_repository.isApiBacked) rethrow;
        resultsRepository = const MockBusRepository();
        buses = await resultsRepository.searchBuses(
          boardingStop: _fromController.text,
          destination: _toController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Backend unavailable. Showing simulated sample data.'),
          ));
        }
      }
      if (!mounted) return;
      try {
        final stops = _availableStops;
        StopOption? findStop(String text) {
          final key = text.trim().toLowerCase();
          for (final stop in stops) {
            if (stop.name.trim().toLowerCase() == key ||
                stop.stopId.toLowerCase() == key) {
              return stop;
            }
          }
          return null;
        }

        final from = findStop(_fromController.text);
        final to = findStop(_toController.text);
        if (from != null && to != null) {
          await _localStore.recordJourney(RecentJourney(
              fromStopId: from.stopId,
              fromName: from.name,
              toStopId: to.stopId,
              toName: to.name,
              routeId: buses.isEmpty ? null : buses.first.routeId,
              tripId: buses.isEmpty ? null : buses.first.tripId,
              searchedAt: DateTime.now()));
          await _loadRecentJourneys();
        }
      } catch (_) {/* A local-history write must not suppress valid results. */}
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BusResultsScreen(
          boardingStop: _fromController.text.trim(),
          destination: _toController.text.trim(),
          buses: buses,
          repository: resultsRepository,
        ),
      ));
    } on BusRepositoryException catch (error) {
      if (mounted) _showSearchError(error.message);
    } on ApiClientException catch (error) {
      if (mounted) _showSearchError(error.message);
    } on FormatException {
      if (mounted) {
        _showSearchError('The backend returned data this app could not read.');
      }
    } catch (_) {
      if (mounted) {
        _showSearchError('Could not search buses. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _showSearchError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(
            label: 'Retry', onPressed: () => unawaited(_searchBuses())),
      ));
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Choose a stop to continue.'
      : null;

  void _swapStops() {
    final from = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = from;
  }

  void _selectQuickAction(int index) {
    if (index == 0) {
      setState(() => _selectedTab = 1);
    } else if (index == 1) {
      setState(() => _selectedTab = 2);
    } else {
      _openFavourites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeBody(),
      _searchBody(),
      TripsScreen(
        key: ValueKey(_recentJourneys.isEmpty
            ? 'empty'
            : '${_recentJourneys.first.key}:${_recentJourneys.first.searchedAt}'),
        onOpenJourney: _replayJourney,
      ),
      ProfileScreen(
        store: _localStore,
        demoEmail: widget.demoEmail,
        onSignOut: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onOpenFavourites: _openFavourites,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_selectedTab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: .13),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined), label: 'Trips'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _homeBody() => CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 26),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _header(),
                const SizedBox(height: 22),
                _location(),
                const SizedBox(height: 21),
                _journeySearchCard(compact: true),
                const SizedBox(height: 22),
                _sectionTitle('Quick access', trailing: ''),
                const SizedBox(height: 12),
                _quickActions(),
                const SizedBox(height: 24),
                _sectionTitle('Recommended for you', trailing: 'Mock data'),
                const SizedBox(height: 12),
                BusCard(
                  bus: _recommendedBus(),
                  onTap: () => _openDetails(_recommendedBus()),
                ),
                const SizedBox(height: 23),
                _sectionTitle('Recent journeys', trailing: 'See all',
                    onTrailing: () {
                  setState(() => _selectedTab = 2);
                }),
                const SizedBox(height: 8),
                ..._recentJourneyCards(),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Seat availability shown here is sample data.',
                    style:
                        TextStyle(color: AppColors.secondaryText, fontSize: 11),
                  ),
                ),
              ]),
            ),
          ),
        ],
      );

  Widget _searchBody() => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pageTitle(
              'Plan your journey', 'Compare expected seats before you board.'),
          const SizedBox(height: 20),
          _location(),
          const SizedBox(height: 18),
          _journeySearchCard(),
          const SizedBox(height: 18),
          _sectionTitle('Recent journeys', trailing: ''),
          const SizedBox(height: 8),
          ..._recentJourneyCards(),
        ]),
      );

  Widget _header() => Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/images/safarsetu-logo-dark.jpg',
              width: 82, height: 48, fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good morning',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            SizedBox(height: 3),
            Text('Ready for your next trip?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ]),
        ),
        IconButton(
          tooltip: 'ETM simulation',
          onPressed: _openEtmSimulation,
          style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(44, 44)),
          icon: const Icon(Icons.science_outlined,
              color: AppColors.accent, size: 21),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => setState(() => _selectedTab = 3),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.person_outline_rounded,
              color: AppColors.secondaryText, size: 21),
        ),
      ]);

  // Mock location for this frontend phase; replace with GPS-backed state later.
  Widget _location() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.location_on_outlined,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR LOCATION',
                  style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 9,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Greater Noida',
                  style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Live location will be available soon.')),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size(52, 44),
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
            child: const Text('Change'),
          ),
        ]),
      );

  Widget _journeySearchCard({bool compact = false}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(compact ? 'Where are you going?' : 'Your journey',
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 15),
            _stopField(
              controller: _fromController,
              label: 'FROM',
              hint: 'Boarding point',
              icon: Icons.trip_origin_rounded,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 19),
              child: Row(children: [
                Container(width: 1, height: 12, color: AppColors.border),
                const Spacer(),
                IconButton(
                  onPressed: _swapStops,
                  tooltip: 'Swap stops',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.swap_vert_rounded,
                      color: AppColors.accent, size: 20),
                ),
              ]),
            ),
            _stopField(
              controller: _toController,
              label: 'TO',
              hint: 'Destination',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 51,
              child: FilledButton.icon(
                onPressed: _searching ? null : _searchBuses,
                icon: _searching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.background),
                      )
                    : const Icon(Icons.search_rounded, size: 20),
                label: Text(_searching ? 'Finding buses…' : 'Search Buses'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: .65),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _stopField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) =>
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        validator: _required,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: AppColors.accent),
          filled: true,
          fillColor: AppColors.background.withValues(alpha: .42),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          labelStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 10, letterSpacing: .8),
          hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.accent)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.error)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.error)),
        ),
      );

  Widget _quickActions() => Row(children: [
        _quickAction(Icons.near_me_outlined, 'Nearby buses', 0),
        const SizedBox(width: 9),
        _quickAction(Icons.history_rounded, 'Recent trips', 1),
        const SizedBox(width: 9),
        _quickAction(Icons.bookmark_border_rounded, 'Saved routes', 2),
      ]);

  Widget _quickAction(IconData icon, String label, int index) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectQuickAction(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 9)),
            ]),
          ),
        ),
      );

  Widget _sectionTitle(String title,
          {required String trailing, VoidCallback? onTrailing}) =>
      Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        if (trailing.isNotEmpty)
          TextButton(
            onPressed: onTrailing,
            style: TextButton.styleFrom(
              foregroundColor: trailing == 'Mock data'
                  ? AppColors.secondaryText
                  : AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(40, 38),
            ),
            child: Text(trailing, style: const TextStyle(fontSize: 11)),
          ),
      ]);

  List<Widget> _recentJourneyCards() => _recentJourneys.isEmpty
      ? [
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No recent journeys yet.',
                  style: TextStyle(color: AppColors.secondaryText)))
        ]
      : [
          for (final journey in _recentJourneys.take(3)) _recentJourney(journey)
        ];

  void _replayJourney(RecentJourney journey) {
    _fromController.text = journey.fromName;
    _toController.text = journey.toName;
    setState(() => _selectedTab = 1);
    unawaited(_searchBuses(validateForm: false));
  }

  Widget _recentJourney(RecentJourney journey) => InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _replayJourney(journey),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            const Icon(Icons.history_rounded,
                size: 19, color: AppColors.secondaryText),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${journey.fromName} → ${journey.toName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.primaryText, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                        journey.searchedAt
                                ?.toLocal()
                                .toString()
                                .split('.')
                                .first ??
                            'Saved search',
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 11)),
                  ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.secondaryText),
          ]),
        ),
      );

  Widget _pageTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 14)),
        ],
      );

  Bus _recommendedBus() => const Bus(
        busId: 'BUS 102',
        route: 'Knowledge Park II → Pari Chowk',
        currentOccupancy: 32,
        capacity: 50,
        predictedOccupancy: 25,
        etaMinutes: 10,
        boardingStop: 'Knowledge Park II',
        destination: 'Pari Chowk',
        routeId: 'SIM-GN-001',
        boardingStopId: 'KP_II',
        destinationStopId: 'PARI_CHOWK',
        currentLocation: 'Knowledge Park III',
        recommendation: 'Lower predicted occupancy',
      );

  void _openDetails(Bus bus) {
    final detailsRepository =
        bus.source == BusDataSource.mock && _repository.isApiBacked
            ? const MockBusRepository()
            : _repository;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BusDetailsScreen(bus: bus, repository: detailsRepository),
    ));
  }

  void _openEtmSimulation() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EtmSimulationScreen(apiEnabled: _repository.isApiBacked),
    ));
  }

  void _openFavourites() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Favourite routes')),
        body: FavouriteRoutesScreen(onOpenRoute: (route) {
          Navigator.of(context).pop();
          _fromController.text = route.fromName;
          _toController.text = route.toName;
          setState(() => _selectedTab = 1);
          unawaited(Future<void>.delayed(
              const Duration(milliseconds: 80), _searchBuses));
        }),
      ),
    ));
  }
}
