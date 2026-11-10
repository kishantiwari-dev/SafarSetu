package in.safarsetu.backend.service;

import in.safarsetu.backend.dto.*;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;
import jakarta.annotation.PostConstruct;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.LinkedHashSet;

@Service
@Transactional(readOnly = true)
public class BusService {
    private static final String CALCULATION_CONVENTION = "AFTER_STOP_EVENTS";
    private static final Duration LOCATION_STALE_AFTER = Duration.ofMinutes(15);
    @Value("${safarsetu.freshness.location-stale-after:PT15M}")
    private Duration locationStaleAfter = LOCATION_STALE_AFTER;
    @Value("${safarsetu.freshness.occupancy-stale-after:PT30M}")
    private Duration occupancyStaleAfter = Duration.ofMinutes(30);
    @Value("${safarsetu.crowding.moderate-percent:40}")
    private int moderateCrowdingPercent = 40;
    @Value("${safarsetu.crowding.high-percent:70}")
    private int highCrowdingPercent = 70;
    @Value("${safarsetu.crowding.nearly-full-percent:90}")
    private int nearlyFullCrowdingPercent = 90;

    private final BusRepository buses;
    private final RouteRepository routes;
    private final StopRepository stops;
    private final RouteStopRepository routeStops;
    private final TicketRepository tickets;
    private final PassengerBookingRepository bookings;
    private final BusLocationRepository locations;
    private final OccupancyCalculator calculator = new OccupancyCalculator();

    public BusService(BusRepository buses, RouteRepository routes, StopRepository stops,
                      RouteStopRepository routeStops, TicketRepository tickets,
                      PassengerBookingRepository bookings, BusLocationRepository locations) {
        this.buses = buses;
        this.routes = routes;
        this.stops = stops;
        this.routeStops = routeStops;
        this.tickets = tickets;
        this.bookings = bookings;
        this.locations = locations;
    }

    @PostConstruct
    void validateFreshnessAndCrowdingConfiguration() {
        if (locationStaleAfter.isNegative() || locationStaleAfter.isZero()
                || occupancyStaleAfter.isNegative() || occupancyStaleAfter.isZero()) {
            throw new IllegalStateException("Freshness thresholds must be positive ISO-8601 durations.");
        }
        if (moderateCrowdingPercent < 1 || moderateCrowdingPercent >= highCrowdingPercent
                || highCrowdingPercent >= nearlyFullCrowdingPercent || nearlyFullCrowdingPercent > 100) {
            throw new IllegalStateException("Crowding thresholds must satisfy 1 <= moderate < high < nearly-full <= 100.");
        }
    }

    public Page<BusDto> listBuses(Pageable pageable) {
        return buses.findAll(bounded(pageable)).map(this::busDto);
    }

    public BusDto getBus(String id) {
        return busDto(buses.findById(id).orElseThrow(() -> ApiException.notFound("Bus not found: " + id)));
    }

    public Page<BusDto> search(String fromId, String toId, Pageable pageable) {
        if (fromId.equals(toId)) throw ApiException.badRequest("Boarding and destination stops must differ");
        requireStop(fromId);
        requireStop(toId);
        List<String> routeIds = routeStops.findRoutesServingJourney(fromId, toId).stream().map(Route::getId).toList();
        if (routeIds.isEmpty()) {
            if (!routeStops.findRoutesServingJourney(toId, fromId).isEmpty()) {
                throw ApiException.badRequest("Boarding stop must precede destination stop on the route");
            }
            return Page.empty(bounded(pageable));
        }
        return buses.findByRoute_IdInAndActiveTrue(routeIds, bounded(pageable)).map(this::busDto);
    }

    public Page<RouteDto> listRoutes(Pageable pageable) {
        Page<Route> page = routes.findAll(bounded(pageable));
        List<String> routeIds = page.getContent().stream().map(Route::getId).toList();
        java.util.Map<String, List<RouteStop>> sequences = new java.util.HashMap<>();
        if (!routeIds.isEmpty()) {
            routeStops.findAllForRoutes(routeIds)
                    .forEach(routeStop -> sequences.computeIfAbsent(routeStop.getRoute().getId(), ignored -> new ArrayList<>()).add(routeStop));
        }
        return page.map(route -> routeDto(route, validatedRouteSequence(route.getId(), sequences.getOrDefault(route.getId(), List.of()))));
    }

    public RouteDto getRoute(String routeId) {
        Route route = routes.findById(routeId)
                .orElseThrow(() -> ApiException.notFound("Route not found: " + routeId));
        List<RouteStop> sequence = requireRouteSequence(route.getId());
        return routeDto(route, sequence);
    }

    public List<StopDto> routeStops(String routeId) {
        if (!routes.existsById(routeId)) throw ApiException.notFound("Route not found: " + routeId);
        return requireRouteSequence(routeId).stream()
                .map(routeStop -> stopDto(routeStop.getStop(), routeStop.getStopOrder())).toList();
    }

    public LocationDto location(String busId) {
        Bus bus = buses.findById(busId).orElseThrow(() -> ApiException.notFound("Bus not found: " + busId));
        BusLocation latest = locations.findFirstByBus_IdOrderByRecordedAtDesc(busId)
                .orElseThrow(() -> ApiException.notFound("No location has been recorded for bus: " + busId));
        if (latest.getBus() == null || !busId.equals(latest.getBus().getId())) {
            throw ApiException.conflict("Latest location is associated with an inconsistent bus");
        }
        if (!validCoordinates(latest.getLatitude(), latest.getLongitude())) {
            throw ApiException.conflict("Latest bus location has invalid coordinates");
        }
        if (latest.getRecordedAt() == null || latest.getDataOrigin() == null) {
            throw ApiException.conflict("Latest bus location is missing its timestamp or source classification");
        }
        Instant now = Instant.now();
        boolean stale = !latest.getRecordedAt().isAfter(now)
                && Duration.between(latest.getRecordedAt(), now).compareTo(locationStaleAfter) > 0;
        String freshness = latest.getDataOrigin() == DataOrigin.SIMULATED ? "SIMULATED"
                : latest.getRecordedAt().isAfter(now) ? "UNKNOWN"
                : stale ? "STALE" : "FRESH";
        return new LocationDto(bus.getId(), latest.getLatitude(), latest.getLongitude(), latest.getRecordedAt(),
                latest.getDataOrigin().name(), stale, freshness);
    }

    public Page<StopDto> listStops(Pageable pageable) {
        return stops.findAll(bounded(pageable)).map(stop -> stopDto(stop, null));
    }

    public OccupancyDto occupancy(String busId, String stopId) {
        return occupancy(busId, stopId, null);
    }

    public OccupancyDto occupancy(String busId, String stopId, String requestedTripId) {
        if (requestedTripId != null && requestedTripId.isBlank()) {
            throw ApiException.badRequest("Trip identifier must not be blank");
        }
        Bus bus = buses.findById(busId).orElseThrow(() -> ApiException.notFound("Bus not found: " + busId));
        List<RouteStop> sequence = requireRouteSequence(bus);
        Instant calculatedAt = Instant.now();

        if (stopId != null) {
            Stop requestedStop = requireStop(stopId);
            int order = RouteStopSequence.indexOf(sequence, requestedStop.getId());
            if (order < 0) throw ApiException.badRequest("Stop is not on the bus route");
            return calculateAtStop(bus, sequence, sequence.get(order), calculatedAt, List.of(), requestedTripId);
        }

        BusLocation latest = locations.findFirstByBus_IdOrderByRecordedAtDesc(busId).orElse(null);
        if (latest == null) {
            return unknownResult(bus, calculatedAt, "NO_LOCATION",
                    List.of("NO_LOCATION: no location record is available to select a route stop."));
        }
        if (latest.getBus() == null || !busId.equals(latest.getBus().getId())) {
            throw ApiException.conflict("Latest location is associated with an inconsistent bus");
        }
        if (!validCoordinates(latest.getLatitude(), latest.getLongitude())) {
            throw ApiException.conflict("Latest bus location has invalid coordinates");
        }
        RouteStop closest = sequence.stream().min((left, right) -> Double.compare(
                distanceMeters(latest.getLatitude(), latest.getLongitude(), left.getStop().getLatitude(), left.getStop().getLongitude()),
                distanceMeters(latest.getLatitude(), latest.getLongitude(), right.getStop().getLatitude(), right.getStop().getLongitude())))
                .orElseThrow(() -> ApiException.conflict("Bus route has no selectable stops"));
        List<String> warnings = new ArrayList<>();
        if (latest.getRecordedAt() == null) throw ApiException.conflict("Latest bus location has no timestamp");
        if (latest.getRecordedAt().isAfter(calculatedAt)) {
            warnings.add("FUTURE_LOCATION: location timestamp is in the future.");
        } else if (Duration.between(latest.getRecordedAt(), calculatedAt).compareTo(locationStaleAfter) > 0) {
            warnings.add("STALE_LOCATION: the route stop was inferred from a location older than the configured threshold ("
                    + locationStaleAfter + ").");
        }
        return calculateAtStop(bus, sequence, closest, calculatedAt, warnings, requestedTripId);
    }

    private OccupancyDto calculateAtStop(Bus bus, List<RouteStop> sequence, RouteStop routeStop,
                                         Instant calculatedAt, List<String> locationWarnings, String requestedTripId) {
        validateCapacity(bus);
        List<Ticket> ticketRows = tickets.findByBus_IdOrderByBoardedAtAsc(bus.getId());
        if (ticketRows == null) throw ApiException.conflict("Ticket repository returned no result set");

        List<PassengerBooking> bookingRows = bookings.findByBus_Id(bus.getId());
        if (bookingRows == null) throw ApiException.conflict("Booking repository returned no result set");

        Set<String> tripIds = new LinkedHashSet<>();
        boolean hasUnassignedTickets = false;
        for (Ticket ticket : ticketRows) {
            if (ticket == null || ticket.getBus() == null || !bus.getId().equals(ticket.getBus().getId())) {
                throw ApiException.conflict("Ticket data contains a record for a different bus");
            }
            if (ticket.getTripId() == null) {
                hasUnassignedTickets = true;
            } else if (ticket.getTripId().isBlank()) {
                throw ApiException.conflict("Ticket data contains a blank trip identifier");
            } else {
                tripIds.add(ticket.getTripId());
            }
        }
        for (PassengerBooking booking : bookingRows) {
            if (booking == null || booking.getBus() == null || !bus.getId().equals(booking.getBus().getId())) {
                throw ApiException.conflict("Booking data contains a record for a different bus");
            }
            if ("CONFIRMED_SIMULATION".equals(booking.getStatus())) {
                if (booking.getTripId() == null || booking.getTripId().isBlank()) {
                    throw ApiException.conflict("Confirmed booking data contains no valid trip identifier");
                }
                tripIds.add(booking.getTripId());
            }
        }

        String selectedTripId = requestedTripId;
        if (selectedTripId == null) {
            if (tripIds.size() > 1 || (tripIds.isEmpty() && hasUnassignedTickets)) {
                return unknownAtStop(bus, routeStop, calculatedAt, null, "TRIP_CONTEXT_REQUIRED",
                        List.of("TRIP_CONTEXT_REQUIRED: ticket or confirmed booking records span multiple trips or have no trip identifier; supply tripId to avoid combining journeys."));
            }
            if (tripIds.size() == 1) selectedTripId = tripIds.iterator().next();
        }

        final String tripIdForSelection = selectedTripId;
        List<Ticket> selectedRows = tripIdForSelection == null ? List.of()
                : ticketRows.stream().filter(ticket -> tripIdForSelection.equals(ticket.getTripId())).toList();
        List<OccupancyCalculator.Journey> ticketJourneys = new ArrayList<>();
        List<OccupancyCalculator.Journey> reservationJourneys = new ArrayList<>();
        Set<String> linkedBookingIds = new HashSet<>();
        Set<DataOrigin> origins = EnumSet.noneOf(DataOrigin.class);
        Instant dataUpdatedAt = null;
        for (Ticket ticket : selectedRows) {
            if (ticket.getBoardingStop() == null || ticket.getDestinationStop() == null
                    || ticket.getBoardedAt() == null || ticket.getDataOrigin() == null) {
                throw ApiException.conflict("Ticket data is incomplete");
            }
            int boardingOrder = RouteStopSequence.indexOf(sequence, ticket.getBoardingStop().getId());
            int destinationOrder = RouteStopSequence.indexOf(sequence, ticket.getDestinationStop().getId());
            if (ticket.getBooking() != null) {
                PassengerBooking linked = ticket.getBooking();
                if (linked.getBus() == null || !bus.getId().equals(linked.getBus().getId())
                        || !tripIdForSelection.equals(linked.getTripId())
                        || linked.getBoardingStop() == null || !ticket.getBoardingStop().getId().equals(linked.getBoardingStop().getId())
                        || linked.getDestinationStop() == null || !ticket.getDestinationStop().getId().equals(linked.getDestinationStop().getId())
                        || linked.getPassengerCount() != ticket.getPassengerCount()) {
                    throw ApiException.conflict("Linked booking does not match its ticket journey");
                }
                linkedBookingIds.add(linked.getId());
            }
            ticketJourneys.add(new OccupancyCalculator.Journey(ticket.getId(), ticket.getPassengerCount(), boardingOrder, destinationOrder));
            origins.add(ticket.getDataOrigin());
            if (dataUpdatedAt == null || ticket.getBoardedAt().isAfter(dataUpdatedAt)) dataUpdatedAt = ticket.getBoardedAt();
        }

        for (PassengerBooking booking : bookingRows) {
            if (!"CONFIRMED_SIMULATION".equals(booking.getStatus()) || tripIdForSelection == null
                    || !tripIdForSelection.equals(booking.getTripId())
                    || linkedBookingIds.contains(booking.getId())) continue;
            if (booking.getBoardingStop() == null || booking.getDestinationStop() == null || booking.getCreatedAt() == null) {
                throw ApiException.conflict("Confirmed booking data is incomplete");
            }
            int boardingOrder = RouteStopSequence.indexOf(sequence, booking.getBoardingStop().getId());
            int destinationOrder = RouteStopSequence.indexOf(sequence, booking.getDestinationStop().getId());
            reservationJourneys.add(new OccupancyCalculator.Journey(booking.getId(), booking.getPassengerCount(), boardingOrder, destinationOrder));
            origins.add(DataOrigin.SIMULATED);
            if (dataUpdatedAt == null || booking.getCreatedAt().isAfter(dataUpdatedAt)) dataUpdatedAt = booking.getCreatedAt();
        }

        final OccupancyCalculator.Result result;
        final OccupancyCalculator.Result reservationResult;
        final OccupancyCalculator.Result combinedResult;
        try {
            result = calculator.atStop(ticketJourneys, routeStop.getStopOrder(), sequence.size(), bus.getTotalPassengerCapacity());
            reservationResult = calculator.atStop(reservationJourneys, routeStop.getStopOrder(), sequence.size(), null);
            List<OccupancyCalculator.Journey> combinedJourneys = new ArrayList<>(ticketJourneys);
            combinedJourneys.addAll(reservationJourneys);
            combinedResult = calculator.atStop(combinedJourneys, routeStop.getStopOrder(), sequence.size(), bus.getTotalPassengerCapacity());
        } catch (IllegalArgumentException | IllegalStateException ex) {
            throw ApiException.conflict("Inconsistent occupancy data: " + ex.getMessage());
        }

        List<String> warnings = new ArrayList<>(locationWarnings);
        if (hasUnassignedTickets) {
            warnings.add("UNASSIGNED_TICKETS_EXCLUDED: legacy ticket records without a trip identifier were excluded from this estimate.");
        }
        Integer provisionalAvailableSeats = null;
        List<String> assumption = new ArrayList<>();
        assumption.add("Route-stop estimate applies boardOrder <= queryOrder and destinationOrder > queryOrder.");
        assumption.add("Only ticket rows assigned to the selected trip are used; other trips are excluded.");
        assumption.add("Ticket timestamps do not change the route-position estimate; the result is not a real-time passenger count.");

        if (result.hasEvents()) {
            assumption.add("Provisional seat estimate assumes one onboard passenger occupies one seat; seated counts are unavailable.");
            if (bus.getSeatingCapacity() <= 0) {
                warnings.add("INVALID_SEATING_CAPACITY: provisional seat availability is unknown.");
            } else {
                provisionalAvailableSeats = Math.max(0, bus.getSeatingCapacity() - result.onboardPassengers());
                if (result.onboardPassengers() > bus.getSeatingCapacity()) {
                    warnings.add("OCCUPANCY_EXCEEDS_SEATING_CAPACITY: provisional available seats are negative.");
                }
            }
            if (bus.getTotalPassengerCapacity() == null) {
                warnings.add("TOTAL_PASSENGER_CAPACITY_UNKNOWN: occupancy has no configured total-passenger limit to validate against.");
            }
        } else {
            warnings.add(ticketRows.isEmpty() && requestedTripId == null
                    ? "NO_TICKET_DATA: zero is not an observed passenger count."
                    : "NO_TICKET_DATA_FOR_TRIP: no ticket events are assigned to the selected trip; zero is not an observed passenger count.");
        }
        if (!result.hasEvents() && !reservationJourneys.isEmpty()) {
            warnings.add("NO_TICKET_DATA: confirmed reservations are shown separately; no ticket-derived onboard estimate is available.");
        }
        if (origins.size() > 1) warnings.add("MIXED_TICKET_DATA_ORIGIN: ticket rows contain multiple source classifications.");

        String dataOrigin = origins.size() == 1 ? origins.iterator().next().name()
                : origins.isEmpty() ? bus.getDataOrigin().name() : "MIXED";
        String status = !result.hasEvents() && reservationJourneys.isEmpty() ? "NO_TICKET_DATA"
                : warnings.isEmpty() ? "CALCULATED" : "CALCULATED_WITH_WARNINGS";
        String freshnessStatus = dataUpdatedAt == null ? "MISSING"
                : origins.contains(DataOrigin.SIMULATED) ? "SIMULATED"
                : dataUpdatedAt.isAfter(calculatedAt) ? "UNKNOWN"
                : Duration.between(dataUpdatedAt, calculatedAt).compareTo(occupancyStaleAfter) > 0 ? "STALE" : "FRESH";
        int occupancyPercent = result.hasEvents() && bus.getSeatingCapacity() > 0
                ? (int) Math.round(result.onboardPassengers() * 100.0 / bus.getSeatingCapacity()) : -1;
        String crowdingCategory = occupancyPercent < 0 ? "UNKNOWN"
                : occupancyPercent < moderateCrowdingPercent ? "LOW"
                : occupancyPercent < highCrowdingPercent ? "MODERATE"
                : occupancyPercent < nearlyFullCrowdingPercent ? "HIGH" : "NEARLY_FULL";
        Integer remainingPassengerCapacity = combinedResult.hasEvents() && bus.getTotalPassengerCapacity() != null
                ? bus.getTotalPassengerCapacity() - combinedResult.onboardPassengers() : null;
        return new OccupancyDto(bus.getId(), selectedTripId, bus.getRoute().getId(), bus.getRoute().getName(),
                routeStop.getStop().getId(), routeStop.getStop().getName(), routeStop.getStopOrder(), calculatedAt,
                dataUpdatedAt, freshnessStatus, crowdingCategory,
                result.hasEvents() ? result.onboardPassengers() : null, bus.getSeatingCapacity(),
                bus.getTotalPassengerCapacity(), provisionalAvailableSeats, CALCULATION_CONVENTION, status,
                String.join(" ", assumption), warnings, dataOrigin,
                result.hasEvents() ? result.onboardPassengers() : null,
                reservationResult.onboardPassengers(), remainingPassengerCapacity);
    }

    private OccupancyDto unknownResult(Bus bus, Instant calculatedAt, String status, List<String> warnings) {
        validateCapacity(bus);
        return new OccupancyDto(bus.getId(), null, bus.getRoute().getId(), bus.getRoute().getName(), null, null, null,
                calculatedAt, null, "MISSING", "UNKNOWN", null, bus.getSeatingCapacity(), bus.getTotalPassengerCapacity(), null,
                CALCULATION_CONVENTION, status,
                "Occupancy and provisional seat availability are unknown because no route position is available.",
                warnings, bus.getDataOrigin().name());
    }

    private OccupancyDto unknownAtStop(Bus bus, RouteStop routeStop, Instant calculatedAt, String tripId,
                                       String status, List<String> warnings) {
        validateCapacity(bus);
        return new OccupancyDto(bus.getId(), tripId, bus.getRoute().getId(), bus.getRoute().getName(),
                routeStop.getStop().getId(), routeStop.getStop().getName(), routeStop.getStopOrder(), calculatedAt,
                null, "TRIP_CONTEXT_REQUIRED".equals(status) ? "UNKNOWN" : "MISSING", "UNKNOWN", null,
                bus.getSeatingCapacity(), bus.getTotalPassengerCapacity(), null, CALCULATION_CONVENTION,
                status, "Occupancy and provisional seat availability are unknown until one trip context is selected.",
                warnings, bus.getDataOrigin().name());
    }

    private List<RouteStop> requireRouteSequence(Bus bus) {
        if (bus.getRoute() == null) throw ApiException.conflict("Bus has no assigned route");
        try {
            return RouteStopSequence.requireValid(bus.getRoute().getId(),
                    routeStops.findByRoute_IdOrderByStopOrder(bus.getRoute().getId()));
        } catch (IllegalStateException ex) {
            throw ApiException.conflict("Invalid bus route ordering: " + ex.getMessage());
        }
    }

    private List<RouteStop> requireRouteSequence(String routeId) {
        return validatedRouteSequence(routeId, routeStops.findByRoute_IdOrderByStopOrder(routeId));
    }

    private static List<RouteStop> validatedRouteSequence(String routeId, List<RouteStop> sequence) {
        try {
            return RouteStopSequence.requireValid(routeId, sequence);
        } catch (IllegalStateException ex) {
            throw ApiException.conflict("Invalid route ordering: " + ex.getMessage());
        }
    }

    private static void validateCapacity(Bus bus) {
        if (bus.getSeatingCapacity() <= 0 || (bus.getTotalPassengerCapacity() != null
                && bus.getTotalPassengerCapacity() < bus.getSeatingCapacity())) {
            throw ApiException.conflict("Bus capacity configuration is invalid");
        }
    }

    private Stop requireStop(String id) {
        return stops.findById(id).orElseThrow(() -> ApiException.notFound("Stop not found: " + id));
    }

    private BusDto busDto(Bus bus) {
        return new BusDto(bus.getId(), bus.getFleetCode(), bus.getRoute().getId(), bus.getRoute().getName(),
                bus.getSeatingCapacity(), bus.getTotalPassengerCapacity(), bus.getDataOrigin().name(), bus.isActive());
    }

    private RouteDto routeDto(Route route, List<RouteStop> sequence) {
        return new RouteDto(route.getId(), route.getName(), route.getDataOrigin().name(), route.isActive(),
                sequence.isEmpty() ? null : sequence.getFirst().getStop().getId(),
                sequence.isEmpty() ? null : sequence.getLast().getStop().getId());
    }

    private StopDto stopDto(Stop stop, Integer order) {
        return new StopDto(stop.getId(), stop.getName(), stop.getLatitude(), stop.getLongitude(),
                stop.getVerificationStatus().name(), order);
    }

    private static boolean validCoordinates(double latitude, double longitude) {
        return Double.isFinite(latitude) && Double.isFinite(longitude)
                && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
    }

    private static Pageable bounded(Pageable pageable) {
        return PageRequest.of(pageable.getPageNumber(), Math.max(1, Math.min(pageable.getPageSize(), 100)), pageable.getSort());
    }

    private static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double radius = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 2 * radius * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
