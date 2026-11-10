import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/etm_simulation_repository.dart';
import '../../data/simulated_trip_id.dart';
import '../../models/backend_data.dart';
import 'etm_validation.dart';

class EtmSimulationScreen extends StatefulWidget {
  const EtmSimulationScreen(
      {super.key, required this.apiEnabled, this.gateway});
  final bool apiEnabled;
  final EtmSimulationGateway? gateway;
  @override
  State<EtmSimulationScreen> createState() => _EtmSimulationScreenState();
}

class _EtmSimulationScreenState extends State<EtmSimulationScreen> {
  late final EtmSimulationGateway? _repository;
  final _tripController = TextEditingController();
  final _passengerController = TextEditingController(text: '1');
  final _bookingReferenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<SimulatedBusOption> _buses = const [];
  List<StopOption> _stops = const [];
  SimulatedBusOption? _bus;
  String? _boardingStopId, _destinationStopId, _arrivalStopId, _occupancyStopId;
  bool _loading = false, _loadingStops = false, _submittingTicket = false;
  bool _submittingArrival = false, _refreshing = false;
  String? _loadError, _ticketError, _arrivalError, _refreshError;
  String? _ticketAttemptKey,
      _ticketEventId,
      _arrivalAttemptKey,
      _arrivalEventId;
  DateTime? _ticketEventAt, _arrivalEventAt;
  SimulatedEventReceipt? _ticketReceipt, _arrivalReceipt;
  OccupancyData? _occupancy;

  @override
  void initState() {
    super.initState();
    _repository = widget.apiEnabled
        ? widget.gateway ??
            EtmSimulationRepository(
                ApiClient(baseUrl: ApiClient.configuredBaseUrl))
        : widget.gateway;
    if (widget.apiEnabled) unawaited(_loadBuses());
  }

  @override
  void dispose() {
    _tripController.dispose();
    _passengerController.dispose();
    _bookingReferenceController.dispose();
    _repository?.close();
    super.dispose();
  }

  Future<void> _loadBuses() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final buses = await _repository!.listSimulatedBuses();
      if (!mounted) return;
      setState(() {
        _buses = buses;
        _bus = buses.isEmpty ? null : buses.first;
        _tripController.text =
            buses.isEmpty ? '' : _suggestedTripId(buses.first);
      });
      if (buses.isNotEmpty) await _loadRoute(buses.first);
    } catch (error) {
      if (mounted) setState(() => _loadError = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _suggestedTripId(SimulatedBusOption bus) {
    return simulatedTripIdForBus(bus.busId);
  }

  Future<void> _loadRoute(SimulatedBusOption bus) async {
    setState(() {
      _loadingStops = true;
      _stops = const [];
      _boardingStopId = null;
      _destinationStopId = null;
      _arrivalStopId = null;
      _occupancyStopId = null;
      _occupancy = null;
      _refreshError = null;
      _ticketReceipt = null;
      _arrivalReceipt = null;
      _ticketAttemptKey = null;
      _arrivalAttemptKey = null;
    });
    try {
      final stops = await _repository!.routeStops(bus);
      if (!mounted || _bus?.busId != bus.busId) return;
      setState(() {
        _stops = stops;
        _boardingStopId = stops.isEmpty ? null : stops.first.stopId;
        _destinationStopId = stops.length < 2 ? null : stops[1].stopId;
        _arrivalStopId = stops.isEmpty ? null : stops.first.stopId;
        _occupancyStopId = stops.isEmpty ? null : stops.first.stopId;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = _message(error));
    } finally {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  String? _validateTrip(String? value) => validateSimulatedTripId(value);
  String? _validatePassengers(String? value) =>
      validateSimulatedPassengerCount(value);
  String? _validateJourney(String? value) =>
      validSimulatedJourney(_stops, _boardingStopId, _destinationStopId)
          ? null
          : 'Destination must follow boarding on this route.';

  String _ticketKey() =>
      '${_bus?.busId}|${_tripController.text.trim()}|$_boardingStopId|$_destinationStopId|${_passengerController.text.trim()}|${_bookingReferenceController.text.trim()}';
  String _arrivalKey() =>
      '${_bus?.busId}|${_tripController.text.trim()}|$_arrivalStopId';
  String _newEventId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _submitTicket() async {
    if (_submittingTicket ||
        _repository == null ||
        !_formKey.currentState!.validate() ||
        _bus == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    final attemptKey = _ticketKey();
    if (_ticketAttemptKey != attemptKey) {
      _ticketAttemptKey = attemptKey;
      _ticketEventId = _newEventId('SIM-TKT');
      _ticketEventAt = DateTime.now().toUtc();
    }
    final eventId = _ticketEventId!;
    final eventAt = _ticketEventAt!;
    final boarding = _boardingStopId!;
    setState(() {
      _submittingTicket = true;
      _ticketError = null;
      _ticketReceipt = null;
    });
    try {
      final receipt = await _repository.submitTicket(
        ticketId: eventId,
        idempotencyKey: 'IDEM-$eventId',
        busId: _bus!.busId,
        boardingStopId: boarding,
        destinationStopId: _destinationStopId!,
        passengerCount: int.parse(_passengerController.text.trim()),
        tripId: _tripController.text.trim(),
        boardedAt: eventAt,
        bookingReference: _bookingReferenceController.text.trim().isEmpty
            ? null
            : _bookingReferenceController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _ticketReceipt = receipt;
        _ticketEventId = null;
        _ticketAttemptKey = null;
        _ticketEventAt = null;
        _occupancy = null;
        _occupancyStopId = boarding;
      });
      await _refreshOccupancy(stopId: boarding);
    } catch (error) {
      if (mounted) setState(() => _ticketError = _message(error));
    } finally {
      if (mounted) setState(() => _submittingTicket = false);
    }
  }

  Future<void> _submitArrival() async {
    if (_submittingArrival ||
        _repository == null ||
        _bus == null ||
        _stops.isEmpty) {
      return;
    }
    if (_validateTrip(_tripController.text) != null || _arrivalStopId == null) {
      setState(() =>
          _arrivalError = 'Choose a simulated bus, trip, and arrival stop.');
      return;
    }
    final attemptKey = _arrivalKey();
    if (_arrivalAttemptKey != attemptKey) {
      _arrivalAttemptKey = attemptKey;
      _arrivalEventId = _newEventId('SIM-ARR');
      _arrivalEventAt = DateTime.now().toUtc();
    }
    final eventId = _arrivalEventId!;
    final eventAt = _arrivalEventAt!;
    final stopId = _arrivalStopId!;
    setState(() {
      _submittingArrival = true;
      _arrivalError = null;
      _arrivalReceipt = null;
    });
    try {
      final receipt = await _repository.submitArrival(
        eventId: eventId,
        tripId: _tripController.text.trim(),
        busId: _bus!.busId,
        stopId: stopId,
        arrivedAt: eventAt,
      );
      if (!mounted) return;
      setState(() {
        _arrivalReceipt = receipt;
        _arrivalEventId = null;
        _arrivalAttemptKey = null;
        _arrivalEventAt = null;
        _occupancy = null;
        _occupancyStopId = stopId;
      });
      await _refreshOccupancy(stopId: stopId);
    } catch (error) {
      if (mounted) setState(() => _arrivalError = _message(error));
    } finally {
      if (mounted) setState(() => _submittingArrival = false);
    }
  }

  Future<void> _refreshOccupancy({String? stopId}) async {
    final bus = _bus;
    final selectedStop = stopId ?? _occupancyStopId;
    final trip = _tripController.text.trim();
    if (_repository == null ||
        bus == null ||
        selectedStop == null ||
        trip.isEmpty) {
      return;
    }
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final data = await _repository.occupancy(
          busId: bus.busId, stopId: selectedStop, tripId: trip);
      if (mounted) setState(() => _occupancy = data);
    } catch (error) {
      if (mounted) setState(() => _refreshError = _message(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _message(Object error) => error is ApiClientException
      ? error.message
      : error is FormatException
          ? error.message
          : 'The simulated event could not be completed. Check the backend and try again.';

  @override
  Widget build(BuildContext context) {
    if (!widget.apiEnabled) return _apiModeRequired();
    return Scaffold(
      appBar: AppBar(title: const Text('ETM simulation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorPanel(_loadError!, _loadBuses)
              : _buses.isEmpty
                  ? _emptyBuses()
                  : _formBody(),
    );
  }

  Widget _apiModeRequired() => Scaffold(
        appBar: AppBar(title: const Text('ETM simulation')),
        body: const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'This workflow requires API mode. Restart with SAFARSETU_DATA_SOURCE=api and SAFARSETU_API_BASE_URL set to the local backend URL. Mock-data mode remains unchanged.',
              textAlign: TextAlign.center),
        )),
      );

  Widget _emptyBuses() => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'No active SIMULATED buses are available from the backend.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _loadBuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh buses')),
        ]),
      ));

  Widget _errorPanel(String message, Future<void> Function() retry) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () => unawaited(retry()),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      ));

  Widget _formBody() => Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          _simulatedBanner(),
          const SizedBox(height: 14),
          _contextCard(),
          const SizedBox(height: 14),
          _ticketCard(),
          const SizedBox(height: 14),
          _arrivalCard(),
          const SizedBox(height: 14),
          _occupancyCard(),
          const SizedBox(height: 20),
          const Text(
              'Simulation only. Ticket events do not prove physical boarding. Occupancy is derived from simulated ticket journeys, not an observed passenger count.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
        ],
      ));

  Widget _simulatedBanner() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .1),
            border: Border.all(color: AppColors.accent.withValues(alpha: .4)),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.science_outlined, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(child: Text('SIMULATED events · no ETM device connected'))
        ]),
      );

  Widget _contextCard() => _card(title: 'Simulated bus and trip', children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_bus?.busId),
          initialValue: _bus?.busId,
          decoration: const InputDecoration(labelText: 'SIMULATED bus'),
          items: _buses
              .map((bus) => DropdownMenuItem(
                  value: bus.busId,
                  child: Text('${bus.busId} · ${bus.routeName}',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _submittingTicket || _submittingArrival || _refreshing
              ? null
              : (value) {
                  if (value == null) return;
                  final selectedBus =
                      _buses.firstWhere((item) => item.busId == value);
                  setState(() {
                    _bus = selectedBus;
                    _tripController.text = _suggestedTripId(selectedBus);
                    _loadError = null;
                    _ticketError = null;
                    _arrivalError = null;
                  });
                  unawaited(_loadRoute(selectedBus));
                },
        ),
        if (_loadingStops) const LinearProgressIndicator(),
        if (_stops.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ordered route: ${_stops.map((stop) => stop.name).join(' → ')}',
              style:
                  const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ),
        TextFormField(
          controller: _tripController,
          enabled: !_submittingTicket && !_submittingArrival && !_refreshing,
          maxLength: 64,
          decoration: const InputDecoration(
              labelText: 'Simulated trip identifier',
              helperText:
                  'A string context shared by ticket and arrival events; not a verified service run.'),
          validator: _validateTrip,
          onChanged: (_) => setState(() {
            _ticketReceipt = null;
            _arrivalReceipt = null;
            _occupancy = null;
            _ticketError = null;
            _arrivalError = null;
          }),
        ),
      ]);

  Widget _ticketCard() => _card(title: 'Simulated ticket event', children: [
        _stopDropdown(
            label: 'Boarding stop',
            value: _boardingStopId,
            onChanged: (value) => setState(() {
                  _boardingStopId = value;
                  _ticketError = null;
                  if (_destinationStopId == value) _destinationStopId = null;
                  _ticketReceipt = null;
                })),
        _stopDropdown(
            label: 'Destination stop',
            value: _destinationStopId,
            onChanged: (value) => setState(() {
                  _destinationStopId = value;
                  _ticketReceipt = null;
                  _ticketError = null;
                })),
        FormField<String>(
            validator: _validateJourney,
            builder: (field) => field.hasError
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(field.errorText!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)))
                : const SizedBox.shrink()),
        TextFormField(
            controller: _passengerController,
            enabled: !_submittingTicket && !_submittingArrival && !_refreshing,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Passenger count',
                helperText: 'Positive whole number per simulated event.'),
            validator: _validatePassengers,
            onChanged: (_) => setState(() {
                  _ticketReceipt = null;
                  _ticketError = null;
                })),
        TextFormField(
            controller: _bookingReferenceController,
            enabled: !_submittingTicket && !_submittingArrival && !_refreshing,
            decoration: const InputDecoration(
                labelText: 'ATM booking reference (optional)',
                helperText:
                    'Links this simulated ticket event to the reservation; it is still not verified physical boarding.'),
            onChanged: (_) => setState(() {
                  _ticketReceipt = null;
                  _ticketError = null;
                })),
        if (_ticketError != null) _errorText(_ticketError!),
        if (_ticketReceipt != null)
          _receiptCard('Ticket accepted · SIMULATED',
              'Ticket ${_ticketReceipt!.id} · ${_ticketReceipt!.eventStatus} · ${_ticketReceipt!.passengerCount} passengers · trip ${_ticketReceipt!.tripId}${_ticketReceipt!.bookingReference == null ? '' : ' · booking ${_ticketReceipt!.bookingReference} ${_ticketReceipt!.bookingStatus}'}'),
        if (_refreshError != null && _ticketReceipt != null)
          _errorText(
              'Ticket accepted. Occupancy refresh failed: $_refreshError'),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _submittingTicket ||
                    _submittingArrival ||
                    _refreshing ||
                    _loadingStops ||
                    _stops.length < 2
                ? null
                : _submitTicket,
            icon: _submittingTicket
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.confirmation_number_outlined),
            label: Text(
                _submittingTicket ? 'Submitting…' : 'Submit simulated ticket')),
      ]);

  Widget _arrivalCard() => _card(title: 'Simulated bus arrival', children: [
        _stopDropdown(
            label: 'Arrival stop',
            value: _arrivalStopId,
            onChanged: (value) => setState(() {
                  _arrivalStopId = value;
                  _arrivalReceipt = null;
                  _arrivalError = null;
                })),
        const Text(
            'The backend rejects repeated or backward stops for this bus and trip. Expected alighting comes from simulated tickets.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        if (_arrivalError != null) _errorText(_arrivalError!),
        if (_arrivalReceipt != null)
          _receiptCard('Arrival accepted · SIMULATED',
              'Event ${_arrivalReceipt!.id} · ${_arrivalReceipt!.eventStatus} · stop ${_arrivalReceipt!.stopId} · expected alighting ${_arrivalReceipt!.simulatedAlightingPassengers ?? 'unknown'} (${_arrivalReceipt!.alightingMeaning ?? 'backend reported'})'),
        if (_refreshError != null && _arrivalReceipt != null)
          _errorText(
              'Arrival accepted. Occupancy refresh failed: $_refreshError'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _submittingArrival ||
                    _submittingTicket ||
                    _refreshing ||
                    _loadingStops ||
                    _arrivalStopId == null
                ? null
                : _submitArrival,
            icon: _submittingArrival
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.location_on_outlined),
            label: Text(_submittingArrival
                ? 'Submitting…'
                : 'Record simulated arrival')),
      ]);

  Widget _occupancyCard() {
    final data = _occupancy;
    return _card(
        title: 'SIMULATED occupancy projection',
        trailing: IconButton(
          tooltip: 'Refresh occupancy',
          onPressed: _refreshing ? null : () => unawaited(_refreshOccupancy()),
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        children: [
          if (data == null)
            const Text('Occupancy has not been loaded for this stop and trip.',
                style: TextStyle(color: AppColors.secondaryText))
          else ...[
            Text(
                'Trip ${data.tripId ?? _tripController.text} · ${data.stopName ?? data.stopId ?? 'selected stop'}'),
            const SizedBox(height: 6),
            Text(
                'Ticket-derived estimate: ${data.onboardPassengers?.toString() ?? 'unknown'} passengers · ${data.crowdingCategory}'),
            Text(
                'Estimated seats left: ${data.provisionalAvailableSeats?.toString() ?? 'unknown'} of ${data.seatingCapacity?.toString() ?? 'unknown'}'),
            Text(
                'Source ${data.dataOrigin ?? 'unknown'} · ${data.occupancyStatus ?? 'unknown'}',
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 12)),
            if (data.dataQualityWarnings.isNotEmpty)
              Text(data.dataQualityWarnings.join('\n'),
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 11)),
          ],
          if (_refreshError != null &&
              _ticketReceipt == null &&
              _arrivalReceipt == null)
            _errorText(_refreshError!),
        ]);
  }

  Widget _stopDropdown(
          {required String label,
          required String? value,
          required ValueChanged<String?> onChanged}) =>
      DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: _stops.any((stop) => stop.stopId == value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: _stops
            .map((stop) => DropdownMenuItem(
                value: stop.stopId,
                child: Text('${stop.stopOrder ?? ''}. ${stop.name}',
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: _loadingStops ||
                _stops.isEmpty ||
                _submittingTicket ||
                _submittingArrival ||
                _refreshing
            ? null
            : onChanged,
      );

  Widget _card(
          {required String title,
          required List<Widget> children,
          Widget? trailing}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing
          ]),
          const SizedBox(height: 10),
          ...children.map((child) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child)),
        ]),
      );

  Widget _receiptCard(String title, String detail) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: .3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.accent)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12))
        ]),
      );

  Widget _errorText(String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(message,
          style: TextStyle(color: Theme.of(context).colorScheme.error)));
}
