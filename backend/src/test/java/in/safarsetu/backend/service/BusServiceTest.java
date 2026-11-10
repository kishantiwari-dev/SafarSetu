package in.safarsetu.backend.service;

import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.*;

import java.time.Instant;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class BusServiceTest {
    private final BusRepository buses = mock(BusRepository.class);
    private final RouteRepository routes = mock(RouteRepository.class);
    private final StopRepository stops = mock(StopRepository.class);
    private final RouteStopRepository routeStops = mock(RouteStopRepository.class);
    private final TicketRepository tickets = mock(TicketRepository.class);
    private final PassengerBookingRepository bookings = mock(PassengerBookingRepository.class);
    private final BusLocationRepository locations = mock(BusLocationRepository.class);
    private final BusService service = new BusService(buses, routes, stops, routeStops, tickets, bookings, locations);

    @Test
    void journeySearchReturnsOnlyActiveBusesOnRoutesServingOrderedStops() {
        Route route = new Route("r1", "sim route", DataOrigin.SIMULATED, true);
        Stop from = stop("a", 0);
        Stop to = stop("b", 1);
        when(stops.findById("a")).thenReturn(Optional.of(from));
        when(stops.findById("b")).thenReturn(Optional.of(to));
        when(routeStops.findRoutesServingJourney("a", "b")).thenReturn(List.of(route));
        Bus bus = bus(route, 20, 30);
        when(buses.findByRoute_IdInAndActiveTrue(List.of("r1"), PageRequest.of(0, 10)))
                .thenReturn(new PageImpl<>(List.of(bus)));

        assertEquals("bus", service.search("a", "b", PageRequest.of(0, 10)).getContent().getFirst().busId());
    }

    @Test
    void rejectsReverseJourneyOnSharedRoute() {
        Route route = new Route("r1", "sim route", DataOrigin.SIMULATED, true);
        when(stops.findById("a")).thenReturn(Optional.of(stop("a", 0)));
        when(stops.findById("b")).thenReturn(Optional.of(stop("b", 1)));
        when(routeStops.findRoutesServingJourney("a", "b")).thenReturn(List.of());
        when(routeStops.findRoutesServingJourney("b", "a")).thenReturn(List.of(route));

        assertEquals(400, assertThrows(ApiException.class,
                () -> service.search("a", "b", PageRequest.of(0, 10))).getStatus().value());
    }

    @Test
    void returnsStopsByRouteOrder() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        when(routes.existsById("route")).thenReturn(true);
        var response = service.routeStops("route");
        assertEquals(List.of("a", "b"), response.stream().map(x -> x.stopId()).toList());
        assertEquals(List.of(0, 1), response.stream().map(x -> x.stopOrder()).toList());
    }

    @Test
    void returnsRouteDetailsAndOrderedStopsAndRejectsUnknownOrInvalidRoutes() {
        Route route = new Route("r1", "sim route", DataOrigin.SIMULATED, true);
        List<RouteStop> sequence = List.of(new RouteStop(route, stop("a", 0), 0), new RouteStop(route, stop("b", 1), 1));
        when(routes.findById("r1")).thenReturn(Optional.of(route));
        when(routes.existsById("r1")).thenReturn(true);
        when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(sequence);

        assertEquals("a", service.getRoute("r1").startStopId());
        assertEquals(List.of(0, 1), service.routeStops("r1").stream().map(x -> x.stopOrder()).toList());
        assertEquals(404, assertThrows(ApiException.class, () -> service.getRoute("missing")).getStatus().value());

        when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route, stop("a", 0), 1)));
        assertEquals(409, assertThrows(ApiException.class, () -> service.routeStops("r1")).getStatus().value());
    }

    @Test
    void listsRoutesWithStopsLoadedInDatabaseSequenceAndRejectsBrokenSequences() {
        Route route = new Route("r1", "sim route", DataOrigin.SIMULATED, true);
        Pageable pageable = PageRequest.of(0, 20, Sort.by("id"));
        when(routes.findAll(pageable)).thenReturn(new PageImpl<>(List.of(route), pageable, 1));
        when(routeStops.findAllForRoutes(List.of("r1"))).thenReturn(List.of(
                new RouteStop(route, stop("b", 1), 0), new RouteStop(route, stop("a", 0), 1)));

        var result = service.listRoutes(pageable).getContent().getFirst();
        assertEquals("b", result.startStopId());
        assertEquals("a", result.endStopId());

        when(routeStops.findAllForRoutes(List.of("r1"))).thenReturn(List.of(new RouteStop(route, stop("a", 0), 1)));
        assertEquals(409, assertThrows(ApiException.class, () -> service.listRoutes(pageable)).getStatus().value());
    }

    @Test
    void retrievesLatestLocationAndReportsFreshnessWithoutCallingItLive() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        BusLocation location = new BusLocation("loc", fixture.bus(), 28.01, 77.01, Instant.now(), DataOrigin.SIMULATED);
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc("bus")).thenReturn(Optional.of(location));

        var result = service.location("bus");

        assertEquals("SIMULATED", result.dataOrigin());
        assertEquals("SIMULATED", result.freshnessStatus());
        assertFalse(result.stale());
    }

    @Test
    void returnsNotFoundForMissingBusOrLocationAndLabelsStaleLocation() {
        assertEquals(404, assertThrows(ApiException.class, () -> service.location("missing")).getStatus().value());
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        assertEquals(404, assertThrows(ApiException.class, () -> service.location("bus")).getStatus().value());
        BusLocation stale = new BusLocation("old", fixture.bus(), 28.01, 77.01,
                Instant.now().minusSeconds(16 * 60L), DataOrigin.SIMULATED);
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc("bus")).thenReturn(Optional.of(stale));
        var result = service.location("bus");
        assertTrue(result.stale());
        assertEquals("SIMULATED", result.freshnessStatus());
    }

    @Test
    void estimatesArrivalFromFreshLocationAndOrderedRouteStops() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of());
        Stop start = fixture.stops().getFirst();
        BusLocation location = new BusLocation("loc", fixture.bus(), start.getLatitude(), start.getLongitude(),
                Instant.now().minusSeconds(30), DataOrigin.SIMULATED);
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc("bus")).thenReturn(Optional.of(location));

        var eta = service.eta("bus", "c");

        assertEquals("AVAILABLE", eta.status());
        assertEquals("SIMULATED_ROUTE_ESTIMATE", eta.estimateType());
        assertEquals("SIMULATED", eta.dataOrigin());
        assertTrue(eta.etaMinutes() > 0);
        assertTrue(eta.estimatedRouteDistanceKm() > 0);
        assertTrue(eta.assumption().contains("excludes traffic and live speed"));
    }

    @Test
    void refusesEtaWhenLocationIsMissingOrStale() {
        fixture(20, 30, List.of("a", "b"), List.of());
        assertEquals("NO_LOCATION", service.eta("bus", "b").status());
        BusLocation stale = new BusLocation("old", new Bus("bus", "fleet", 20, 30,
                new Route("route", "sim route", DataOrigin.SIMULATED, true), DataOrigin.SIMULATED, true),
                28.0, 77.0, Instant.now().minusSeconds(16 * 60L), DataOrigin.SIMULATED);
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc("bus")).thenReturn(Optional.of(stale));
        var eta = service.eta("bus", "b");
        assertEquals("STALE_LOCATION", eta.status());
        assertNull(eta.etaMinutes());
    }

    @Test
    void reportsFreshnessAndCrowdingFromRealTicketTimestampsWithoutCallingItRealtime() {
        var fresh = fixture(20, 30, List.of("a", "b", "c"), List.of());
        Ticket real = new Ticket("real-ticket", "key-real", fresh.bus(), fresh.stops().get(0), fresh.stops().get(2),
                22, Instant.now().minusSeconds(60), DataOrigin.REAL, "trip-real");
        when(tickets.findByBus_IdOrderByBoardedAtAsc("bus")).thenReturn(List.of(real));
        var calculated = service.occupancy("bus", "b");
        assertEquals("FRESH", calculated.freshnessStatus());
        assertEquals("NEARLY_FULL", calculated.crowdingCategory());
        assertEquals(real.getBoardedAt(), calculated.dataUpdatedAt());

        Ticket old = new Ticket("old-real-ticket", "key-old", fresh.bus(), fresh.stops().get(0), fresh.stops().get(2),
                22, Instant.now().minusSeconds(3600), DataOrigin.REAL, "trip-real");
        when(tickets.findByBus_IdOrderByBoardedAtAsc("bus")).thenReturn(List.of(old));
        assertEquals("STALE", service.occupancy("bus", "b").freshnessStatus());
    }

    @Test
    void classifiesCrowdingAtConfiguredSeatingCapacityThresholds() {
        assertEquals("LOW", crowdingAt(19));
        assertEquals("MODERATE", crowdingAt(20));
        assertEquals("HIGH", crowdingAt(35));
        assertEquals("NEARLY_FULL", crowdingAt(45));
    }

    private String crowdingAt(int passengers) {
        var fixture = fixture(50, 100, List.of("a", "b", "c"), List.of(
                new TicketSpec("threshold-" + passengers, 0, 2, passengers, Instant.now())));
        return service.occupancy(fixture.bus().getId(), "b").crowdingCategory();
    }

    @Test
    void reportsMissingOrUnknownOccupancyFreshnessRatherThanZero() {
        var missing = fixture(20, 30, List.of("a", "b"), List.of());
        var noEvents = service.occupancy(missing.bus().getId(), "a");
        assertEquals("MISSING", noEvents.freshnessStatus());
        assertEquals("UNKNOWN", noEvents.crowdingCategory());

        Ticket future = new Ticket("future", "key-future", missing.bus(), missing.stops().get(0), missing.stops().get(1),
                1, Instant.now().plusSeconds(600), DataOrigin.REAL, "trip-future");
        when(tickets.findByBus_IdOrderByBoardedAtAsc("bus")).thenReturn(List.of(future));
        assertEquals("UNKNOWN", service.occupancy("bus", "a").freshnessStatus());
    }

    @Test
    void rejectsInvalidCoordinatesInLatestLocation() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        BusLocation invalid = new BusLocation("invalid", fixture.bus(), Double.NaN, 77.01,
                Instant.now(), DataOrigin.SIMULATED);
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc("bus")).thenReturn(Optional.of(invalid));
        assertEquals(409, assertThrows(ApiException.class, () -> service.location("bus")).getStatus().value());
    }

    @Test
    void calculatesTheRequiredPariChowkAlphaDeltaExampleAndProvisionalSeats() {
        var fixture = fixture(40, 50, List.of("PARI_CHOWK", "ALPHA_1", "DELTA_1", "END"), List.of(
                new TicketSpec("to-delta", 0, 2, 8, then("2026-10-01T08:00:00Z")),
                new TicketSpec("to-end-1", 0, 3, 4, then("2026-10-01T08:01:00Z")),
                new TicketSpec("to-end-2", 1, 3, 5, then("2026-10-01T08:02:00Z"))));

        var pari = service.occupancy(fixture.bus().getId(), "PARI_CHOWK");
        var alpha = service.occupancy(fixture.bus().getId(), "ALPHA_1");
        var delta = service.occupancy(fixture.bus().getId(), "DELTA_1");

        assertEquals(12, pari.onboardPassengers());
        assertEquals(17, alpha.onboardPassengers());
        assertEquals(9, delta.onboardPassengers());
        assertEquals(28, pari.provisionalAvailableSeats());
        assertEquals(23, alpha.provisionalAvailableSeats());
        assertEquals(31, delta.provisionalAvailableSeats());
        assertEquals("route", delta.routeId());
        assertEquals("DELTA_1", delta.stopId());
        assertEquals(2, delta.stopOrder());
        assertEquals("AFTER_STOP_EVENTS", delta.calculationConvention());
        assertEquals("trip-1", delta.tripId());
        assertFalse(delta.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("JOURNEY_INSTANCE_UNKNOWN:")));
    }

    @Test
    void returnsTicketAndReservationLoadsSeparatelyAcrossRouteSegments() {
        var fixture = fixture(10, 15, List.of("a", "b", "c", "d"), List.of(
                new TicketSpec("ticket-a-c", 0, 2, 4, then("2026-10-01T08:00:00Z")),
                new TicketSpec("ticket-b-d", 1, 3, 3, then("2026-10-01T08:01:00Z")),
                new TicketSpec("ticket-a-d", 0, 3, 2, then("2026-10-01T08:02:00Z"))));
        var reserveFirstSegment = booking("reserved-a-b", fixture, 0, 1, 5, "trip-1", "CONFIRMED_SIMULATION");
        var reserveMiddleSegment = booking("reserved-b-d", fixture, 1, 3, 4, "trip-1", "CONFIRMED_SIMULATION");
        var otherTrip = booking("other-trip", fixture, 0, 3, 9, "trip-2", "CONFIRMED_SIMULATION");
        var cancelled = booking("cancelled", fixture, 0, 3, 9, "trip-1", "CANCELLED_SIMULATION");
        var rejected = booking("rejected", fixture, 0, 3, 9, "trip-1", "REJECTED_SIMULATION");
        when(bookings.findByBus_Id("bus")).thenReturn(List.of(
                reserveFirstSegment, reserveMiddleSegment, otherTrip, cancelled, rejected));

        var atA = service.occupancy("bus", "a", "trip-1");
        var atB = service.occupancy("bus", "b", "trip-1");
        var atC = service.occupancy("bus", "c", "trip-1");

        assertEquals(6, atA.ticketDerivedOnboardPassengers());
        assertEquals(5, atA.confirmedReservedPassengers());
        assertEquals(4, atA.remainingPassengerCapacity());
        assertEquals(9, atB.ticketDerivedOnboardPassengers());
        assertEquals(4, atB.confirmedReservedPassengers());
        assertEquals(2, atB.remainingPassengerCapacity());
        assertEquals(5, atC.ticketDerivedOnboardPassengers());
        assertEquals(4, atC.confirmedReservedPassengers());
        assertEquals(6, atC.remainingPassengerCapacity());
        assertEquals(atB.ticketDerivedOnboardPassengers(), atB.onboardPassengers());
    }

    @Test
    void linkedTicketCountsOnceAndMovesBookingOutOfReservationTotal() {
        var fixture = fixture(10, 15, List.of("a", "b", "c"), List.of());
        var linkedBooking = booking("booking-linked", fixture, 0, 2, 4, "trip-1", "BOARDING_RECORDED_SIMULATION");
        Ticket linkedTicket = new Ticket("ticket-linked", "ticket-key", fixture.bus(), fixture.stops().get(0),
                fixture.stops().get(2), 4, then("2026-10-01T08:00:00Z"), DataOrigin.SIMULATED,
                "trip-1", linkedBooking);
        when(tickets.findByBus_IdOrderByBoardedAtAsc("bus")).thenReturn(List.of(linkedTicket));
        // Also return a stale confirmed status to prove that the explicit ticket link prevents double counting.
        when(bookings.findByBus_Id("bus")).thenReturn(List.of(
                booking("booking-linked", fixture, 0, 2, 4, "trip-1", "CONFIRMED_SIMULATION")));

        var result = service.occupancy("bus", "b", "trip-1");

        assertEquals(4, result.ticketDerivedOnboardPassengers());
        assertEquals(0, result.confirmedReservedPassengers());
        assertEquals(11, result.remainingPassengerCapacity());
    }

    @Test
    void occupancyIncludesReservationOnlyAndCanInferItsTrip() {
        var fixture = fixture(10, 15, List.of("a", "b", "c"), List.of());
        when(bookings.findByBus_Id("bus")).thenReturn(List.of(
                booking("booking-only", fixture, 0, 2, 4, "trip-1", "CONFIRMED_SIMULATION")));

        var result = service.occupancy("bus", "b");

        assertEquals("trip-1", result.tripId());
        assertNull(result.ticketDerivedOnboardPassengers());
        assertNull(result.onboardPassengers());
        assertEquals(4, result.confirmedReservedPassengers());
        assertEquals(11, result.remainingPassengerCapacity());
        assertEquals("CALCULATED_WITH_WARNINGS", result.occupancyStatus());
    }

    @Test
    void rejectsRecordedCombinedLoadAboveTotalPassengerCapacity() {
        var fixture = fixture(10, 10, List.of("a", "b", "c"), List.of(
                new TicketSpec("ticket", 0, 2, 7, then("2026-10-01T08:00:00Z"))));
        when(bookings.findByBus_Id("bus")).thenReturn(List.of(
                booking("booking", fixture, 0, 2, 4, "trip-1", "CONFIRMED_SIMULATION")));

        assertEquals(409, assertThrows(ApiException.class,
                () -> service.occupancy("bus", "b", "trip-1")).getStatus().value());
    }

    @Test
    void keepsDifferentTripsSeparateAndRequiresContextWhenMoreThanOneTripExists() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of(
                new TicketSpec("trip-one-ticket", 0, 2, 3, then("2026-10-01T08:00:00Z"), "trip-one"),
                new TicketSpec("trip-two-ticket", 1, 2, 8, then("2026-10-02T08:00:00Z"), "trip-two")));
        Ticket legacy = new Ticket("legacy-trip-ticket", "legacy-key", fixture.bus(), fixture.stops().get(0),
                fixture.stops().get(2), 5, then("2026-10-01T07:00:00Z"), DataOrigin.SIMULATED);
        when(tickets.findByBus_IdOrderByBoardedAtAsc(fixture.bus().getId()))
                .thenReturn(List.of(fixture.tickets().get(0), fixture.tickets().get(1), legacy));

        var ambiguous = service.occupancy(fixture.bus().getId(), "b");
        var firstTrip = service.occupancy(fixture.bus().getId(), "b", "trip-one");
        var secondTrip = service.occupancy(fixture.bus().getId(), "b", "trip-two");

        assertEquals("TRIP_CONTEXT_REQUIRED", ambiguous.occupancyStatus());
        assertEquals("UNKNOWN", ambiguous.freshnessStatus());
        assertNull(ambiguous.onboardPassengers());
        assertTrue(ambiguous.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("TRIP_CONTEXT_REQUIRED:")));
        assertEquals(3, firstTrip.onboardPassengers());
        assertTrue(firstTrip.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("UNASSIGNED_TICKETS_EXCLUDED:")));
        assertEquals(8, secondTrip.onboardPassengers());
    }

    @Test
    void refusesToInferTripForLegacyTicketRowsWithoutTripIdentifiers() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        Ticket legacy = new Ticket("legacy", "legacy-key", fixture.bus(), fixture.stops().get(0),
                fixture.stops().get(1), 2, then("2026-10-01T08:00:00Z"), DataOrigin.SIMULATED);
        when(tickets.findByBus_IdOrderByBoardedAtAsc(fixture.bus().getId())).thenReturn(List.of(legacy));

        var result = service.occupancy(fixture.bus().getId(), "a");

        assertEquals("TRIP_CONTEXT_REQUIRED", result.occupancyStatus());
        assertNull(result.onboardPassengers());
    }

    @Test
    void doesNotUseTicketWallClockTimeToChangeRouteStopOccupancy() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of(
                new TicketSpec("old-row", 0, 2, 3, then("2001-01-01T00:00:00Z"))));

        assertEquals(3, service.occupancy(fixture.bus().getId(), "b").onboardPassengers());
    }

    @Test
    void returnsUnknownForMissingTicketsInsteadOfInventingZero() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());

        var result = service.occupancy(fixture.bus().getId(), "a");

        assertNull(result.onboardPassengers());
        assertNull(result.provisionalAvailableSeats());
        assertEquals("NO_TICKET_DATA", result.occupancyStatus());
        assertTrue(result.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("NO_TICKET_DATA:")));
    }

    @Test
    void returnsUnknownWhenNoLocationCanSelectARouteStopAndDoesNotReadSnapshots() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());

        var result = service.occupancy(fixture.bus().getId(), null);

        assertEquals("NO_LOCATION", result.occupancyStatus());
        assertNull(result.stopId());
        assertNull(result.onboardPassengers());
        assertNull(result.provisionalAvailableSeats());
        verify(tickets, never()).findByBus_IdOrderByBoardedAtAsc(fixture.bus().getId());
    }

    @Test
    void infersTheNearestRouteStopFromLocationAndFlagsStaleLocation() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of(
                new TicketSpec("trip", 0, 2, 3, then("2026-10-01T08:00:00Z"))));
        Stop first = fixture.stops().getFirst();
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc(fixture.bus().getId())).thenReturn(Optional.of(
                new BusLocation("loc", fixture.bus(), first.getLatitude(), first.getLongitude(),
                        Instant.now().minusSeconds(3600), DataOrigin.SIMULATED)));

        var result = service.occupancy(fixture.bus().getId(), null);

        assertEquals("a", result.stopId());
        assertEquals(3, result.onboardPassengers());
        assertTrue(result.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("STALE_LOCATION:")));
    }

    @Test
    void distinguishesUnknownStopsFromStopsOnAnotherRoute() {
        var fixture = fixture(20, 30, List.of("a", "b"), List.of());
        when(stops.findById("missing")).thenReturn(Optional.empty());
        Stop otherRouteStop = stop("other", 3);
        when(stops.findById("other")).thenReturn(Optional.of(otherRouteStop));

        assertEquals(404, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "missing"))
                .getStatus().value());
        assertEquals(400, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "other"))
                .getStatus().value());
    }

    @Test
    void unknownBusReturnsNotFound() {
        when(buses.findById("missing")).thenReturn(Optional.empty());
        assertEquals(404, assertThrows(ApiException.class, () -> service.occupancy("missing", "a"))
                .getStatus().value());
    }

    @Test
    void rejectsInvalidRouteStopOrderValues() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of());
        when(routeStops.findByRoute_IdOrderByStopOrder("route")).thenReturn(List.of(
                new RouteStop(fixture.route(), fixture.stops().get(0), 0),
                new RouteStop(fixture.route(), fixture.stops().get(1), 2),
                new RouteStop(fixture.route(), fixture.stops().get(2), 3)));

        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "a"))
                .getStatus().value());
    }

    @Test
    void rejectsTicketsWhoseStopsAreNotOnTheAssignedRoute() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of());
        Stop outsider = stop("outsider", 4);
        Ticket ticket = new Ticket("wrong-route", "key", fixture.bus(), outsider, fixture.stops().get(2),
                1, then("2026-10-01T08:00:00Z"), DataOrigin.SIMULATED, "trip-1");
        when(tickets.findByBus_IdOrderByBoardedAtAsc(fixture.bus().getId())).thenReturn(List.of(ticket));

        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "b"))
                .getStatus().value());
    }

    @Test
    void rejectsStoredTicketWhoseDestinationDoesNotFollowBoarding() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of(
                new TicketSpec("reverse", 2, 1, 1, then("2026-10-01T08:00:00Z"))));
        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "b"))
                .getStatus().value());
    }

    @Test
    void rejectsDuplicateTicketIdentifiersInReturnedData() {
        var fixture = fixture(20, 30, List.of("a", "b", "c"), List.of(
                new TicketSpec("duplicate-id", 0, 2, 1, then("2026-10-01T08:00:00Z"))));
        Ticket duplicate = fixture.tickets().getFirst();
        when(tickets.findByBus_IdOrderByBoardedAtAsc(fixture.bus().getId())).thenReturn(List.of(duplicate, duplicate));

        ApiException failure = assertThrows(ApiException.class,
                () -> service.occupancy(fixture.bus().getId(), "b"));
        assertEquals(409, failure.getStatus().value());
        assertTrue(failure.getMessage().contains("Duplicate ticket identifier"));
    }

    @Test
    void clampsProvisionalSeatEstimateAtZeroWhenCrowdedBeyondSeatingCapacity() {
        var fixture = fixture(40, 55, List.of("a", "b", "c"), List.of(
                new TicketSpec("large-party", 0, 2, 45, then("2026-10-01T08:00:00Z"))));

        var result = service.occupancy(fixture.bus().getId(), "b");

        assertEquals(45, result.onboardPassengers());
        assertEquals(0, result.provisionalAvailableSeats());
        assertTrue(result.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("OCCUPANCY_EXCEEDS_SEATING_CAPACITY:")));
    }

    @Test
    void rejectsOccupancyAboveTotalPassengerCapacity() {
        var fixture = fixture(40, 50, List.of("a", "b", "c"), List.of(
                new TicketSpec("too-many", 0, 2, 51, then("2026-10-01T08:00:00Z"))));
        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(fixture.bus().getId(), "b"))
                .getStatus().value());
    }

    @Test
    void reportsUnknownTotalCapacityAndRejectsInvalidSeatingCapacity() {
        var unknownTotal = fixture(40, null, List.of("a", "b", "c"), List.of(
                new TicketSpec("known-count", 0, 2, 10, then("2026-10-01T08:00:00Z"))));
        var result = service.occupancy(unknownTotal.bus().getId(), "b");
        assertTrue(result.dataQualityWarnings().stream().anyMatch(w -> w.startsWith("TOTAL_PASSENGER_CAPACITY_UNKNOWN:")));

        var invalidSeats = fixture(0, 0, List.of("x", "y"), List.of());
        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(invalidSeats.bus().getId(), "x"))
                .getStatus().value());

        var invalidTotal = fixture(40, 30, List.of("m", "n"), List.of());
        assertEquals(409, assertThrows(ApiException.class, () -> service.occupancy(invalidTotal.bus().getId(), "m"))
                .getStatus().value());
    }

    private Fixture fixture(int seatingCapacity, Integer passengerCapacity, List<String> stopIds,
                            List<TicketSpec> ticketSpecs) {
        Route route = new Route("route", "sim route", DataOrigin.SIMULATED, true);
        Bus bus = bus(route, seatingCapacity, passengerCapacity);
        List<Stop> routeStopsList = new ArrayList<>();
        List<RouteStop> sequence = new ArrayList<>();
        for (int i = 0; i < stopIds.size(); i++) {
            Stop stop = stop(stopIds.get(i), i);
            routeStopsList.add(stop);
            sequence.add(new RouteStop(route, stop, i));
            when(stops.findById(stop.getId())).thenReturn(Optional.of(stop));
        }
        List<Ticket> ticketRows = ticketSpecs.stream().map(spec -> new Ticket(spec.id(), "key-" + spec.id(), bus,
                routeStopsList.get(spec.boardingIndex()), routeStopsList.get(spec.destinationIndex()), spec.passengers(),
                spec.boardedAt(), DataOrigin.SIMULATED, spec.tripId())).toList();

        when(buses.findById(bus.getId())).thenReturn(Optional.of(bus));
        when(routeStops.findByRoute_IdOrderByStopOrder(route.getId())).thenReturn(sequence);
        when(tickets.findByBus_IdOrderByBoardedAtAsc(bus.getId())).thenReturn(ticketRows);
        when(bookings.findByBus_Id(bus.getId())).thenReturn(List.of());
        when(locations.findFirstByBus_IdOrderByRecordedAtDesc(bus.getId())).thenReturn(Optional.empty());
        return new Fixture(route, bus, routeStopsList, ticketRows);
    }

    private PassengerBooking booking(String id, Fixture fixture, int from, int to,
                                     int count, String tripId, String status) {
        return new PassengerBooking(id, "ATM-" + id, "key-" + id, tripId, fixture.bus(),
                fixture.stops().get(from), fixture.stops().get(to), count, status,
                then("2026-10-01T07:00:00Z"));
    }

    private static Bus bus(Route route, int seats, Integer total) {
        return new Bus("bus", "fleet", seats, total, route, DataOrigin.SIMULATED, true);
    }

    private static Stop stop(String id, int index) {
        return new Stop(id, id, 28.0 + index * 0.01, 77.0 + index * 0.01, VerificationStatus.APPROXIMATE);
    }

    private static Instant then(String instant) {
        return Instant.parse(instant);
    }

    private record TicketSpec(String id, int boardingIndex, int destinationIndex, int passengers, Instant boardedAt, String tripId) {
        TicketSpec(String id, int boardingIndex, int destinationIndex, int passengers, Instant boardedAt) {
            this(id, boardingIndex, destinationIndex, passengers, boardedAt, "trip-1");
        }
    }
    private record Fixture(Route route, Bus bus, List<Stop> stops, List<Ticket> tickets) {}
}
