import 'dart:math';

import 'package:flutter/material.dart';

import 'atm_api.dart';

class AtmApp extends StatelessWidget {
  const AtmApp({super.key, required this.api});
  final AtmApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SafarSetu Passenger Kiosk',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff075e54)),
      scaffoldBackgroundColor: const Color(0xfff4f7f6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: AtmHomeScreen(api: api),
  );
}

class AtmHomeScreen extends StatefulWidget {
  const AtmHomeScreen({super.key, required this.api});
  final AtmApi api;
  @override
  State<AtmHomeScreen> createState() => _AtmHomeScreenState();
}

class _AtmHomeScreenState extends State<AtmHomeScreen> {
  late Future<List<AtmStop>> _stopsRequest;
  Future<List<AtmBus>>? _busRequest;
  AtmStop? _from;
  AtmStop? _to;
  AtmBus? _selectedBus;
  AtmBookingReceipt? _receipt;
  int _quantity = 1;
  bool _submitting = false;
  String? _error;
  late String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _stopsRequest = widget.api.loadStops();
    _idempotencyKey = _newKey();
  }

  String _newKey() =>
      'atm-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  void _search() {
    if (_from == null || _to == null) {
      setState(() => _error = 'Choose a boarding stop and destination.');
      return;
    }
    if (_from!.id == _to!.id) {
      setState(() => _error = 'Boarding stop and destination must differ.');
      return;
    }
    setState(() {
      _error = null;
      _selectedBus = null;
      _busRequest = widget.api.searchBuses(
        fromStopId: _from!.id,
        toStopId: _to!.id,
      );
    });
  }

  Future<void> _book() async {
    final bus = _selectedBus;
    final from = _from;
    final to = _to;
    if (bus == null || from == null || to == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await widget.api.createBooking(
        idempotencyKey: _idempotencyKey,
        bus: bus,
        from: from,
        to: to,
        passengerCount: _quantity,
      );
      if (mounted) setState(() => _receipt = receipt);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startAgain() {
    setState(() {
      _receipt = null;
      _busRequest = null;
      _selectedBus = null;
      _from = null;
      _to = null;
      _quantity = 1;
      _error = null;
      _idempotencyKey = _newKey();
      _stopsRequest = widget.api.loadStops();
    });
  }

  void _journeyChanged() => _idempotencyKey = _newKey();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SafarSetu'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: Center(
            child: Chip(
              avatar: Icon(Icons.developer_board, size: 18),
              label: Text('Simulation'),
            ),
          ),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _receipt == null ? _bookingFlow() : _receiptView(_receipt!),
        ),
      ),
    ),
  );

  Widget _bookingFlow() => FutureBuilder<List<AtmStop>>(
    future: _stopsRequest,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _loadError(
          'Could not connect to the SafarSetu backend. ${snapshot.error}',
          () => setState(() => _stopsRequest = widget.api.loadStops()),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final stops = snapshot.data!;
      if (stops.isEmpty) {
        return _loadError(
          'No stops are available from the backend.',
          () => setState(() => _stopsRequest = widget.api.loadStops()),
        );
      }
      return ListView(
        children: [
          const Text(
            'Passenger ticket kiosk',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a journey and reserve passenger capacity. This demonstration uses simulated services only.',
          ),
          const SizedBox(height: 20),
          _notice(
            'No schedule or fare data is configured. No price or departure time is shown.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Your journey',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 390,
                        child: _stopPicker(
                          'Boarding stop',
                          stops,
                          _from,
                          (value) => setState(() {
                            _from = value;
                            _journeyChanged();
                            _busRequest = null;
                            _selectedBus = null;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 390,
                        child: _stopPicker(
                          'Destination',
                          stops,
                          _to,
                          (value) => setState(() {
                            _to = value;
                            _journeyChanged();
                            _busRequest = null;
                            _selectedBus = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Find buses'),
                  ),
                ],
              ),
            ),
          ),
          if (_busRequest != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. Select a simulated bus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<AtmBus>>(
                      future: _busRequest,
                      builder: (context, buses) {
                        if (buses.hasError) {
                          return _loadError(
                            'Bus search failed: ${buses.error}',
                            _search,
                          );
                        }
                        if (!buses.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (buses.data!.isEmpty) {
                          return const Text(
                            'No active simulated bus serves this stop order.',
                          );
                        }
                        return RadioGroup<AtmBus>(
                          groupValue: _selectedBus,
                          onChanged: (value) => setState(() {
                            _selectedBus = value;
                            _journeyChanged();
                          }),
                          child: Column(
                            children: buses.data!
                                .map(
                                  (bus) => RadioListTile<AtmBus>(
                                    value: bus,
                                    title: Text(
                                      '${bus.fleetCode} · ${bus.routeName}',
                                    ),
                                    subtitle: Text(
                                      'Passenger capacity ${bus.capacity ?? 'unknown'} · synthetic trip ${bus.demoTripId}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_selectedBus != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3. Passenger quantity and review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Passengers (no seat selection)'),
                        ),
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() {
                                  _quantity--;
                                  _journeyChanged();
                                })
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _quantity < 20
                              ? () => setState(() {
                                  _quantity++;
                                  _journeyChanged();
                                })
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text('From: ${_from!.name}'),
                    Text('To: ${_to!.name}'),
                    Text(
                      'Bus: ${_selectedBus!.fleetCode} (${_selectedBus!.routeName})',
                    ),
                    Text('Quantity: $_quantity'),
                    const SizedBox(height: 8),
                    const Text(
                      'Booking confirmation reserves simulated segment capacity. It is not proof of boarding.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _book,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.confirmation_number_outlined),
                      label: Text(
                        _submitting
                            ? 'Submitting…'
                            : 'Confirm simulated booking',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_error!),
          ],
        ],
      );
    },
  );

  Widget _stopPicker(
    String label,
    List<AtmStop> stops,
    AtmStop? selected,
    ValueChanged<AtmStop?> onChanged,
  ) => DropdownButtonFormField<AtmStop>(
    initialValue: selected,
    decoration: InputDecoration(labelText: label),
    items: stops
        .map((stop) => DropdownMenuItem(value: stop, child: Text(stop.name)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _receiptView(AtmBookingReceipt receipt) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Simulation booking confirmed',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Reference: ${receipt.reference}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              'Journey: ${receipt.boardingStop} → ${receipt.destinationStop}',
            ),
            Text('Bus: ${receipt.busId} · Trip: ${receipt.tripId}'),
            Text('Passengers: ${receipt.passengerCount}'),
            Text('Status: ${receipt.status} · ${receipt.createdAt.toLocal()}'),
            const SizedBox(height: 12),
            const Text(
              'This reservation is simulated. It does not confirm payment or physical boarding.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startAgain,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Start another booking'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _notice(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfffff5d8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
  Widget _errorBanner(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
  Widget _loadError(String message, VoidCallback retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
