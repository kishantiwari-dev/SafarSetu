package in.safarsetu.backend.service;

import in.safarsetu.backend.dto.PassengerBookingRequest;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class PassengerBookingService {
    private static final String CONFIRMED = "CONFIRMED_SIMULATION";
    private final PassengerBookingRepository bookings;
    private final TicketRepository tickets;
    private final BusRepository buses;
    private final StopRepository stops;
    private final RouteStopRepository routeStops;
    private final OccupancyCalculator calculator = new OccupancyCalculator();

    public PassengerBookingService(PassengerBookingRepository bookings, TicketRepository tickets,
                                   BusRepository buses, StopRepository stops, RouteStopRepository routeStops) {
        this.bookings = bookings;
        this.tickets = tickets;
        this.buses = buses;
        this.stops = stops;
        this.routeStops = routeStops;
    }

    @Transactional
    public BookingReceipt create(PassengerBookingRequest request) {
        if (request == null) throw ApiException.badRequest("Booking request is required");
        var prior = bookings.findByIdempotencyKey(request.idempotencyKey());
        if (prior.isPresent()) return retryReceipt(prior.get(), request);
        Bus bus = buses.findByIdForUpdate(request.busId())
                .orElseThrow(() -> ApiException.notFound("Bus not found: " + request.busId()));
        // Recheck after the shared bus lock so same-key concurrent requests return the first receipt.
        prior = bookings.findByIdempotencyKey(request.idempotencyKey());
        if (prior.isPresent()) return retryReceipt(prior.get(), request);
        if (!bus.isActive() || bus.getDataOrigin() != DataOrigin.SIMULATED)
            throw ApiException.conflict("Simulation bookings require an active SIMULATED bus");
        if (!request.tripId().equals("SIM-TRIP-" + bus.getId() + "-DEMO-01"))
            throw ApiException.badRequest("Trip identifier must match the synthetic demo run for this bus");
        if (bus.getRoute() == null || bus.getTotalPassengerCapacity() == null || bus.getTotalPassengerCapacity() <= 0)
            throw ApiException.conflict("Bus must have a known total passenger capacity for booking");

        Stop from = stops.findById(request.boardingStopId())
                .orElseThrow(() -> ApiException.notFound("Boarding stop not found: " + request.boardingStopId()));
        Stop to = stops.findById(request.destinationStopId())
                .orElseThrow(() -> ApiException.notFound("Destination stop not found: " + request.destinationStopId()));
        List<RouteStop> sequence;
        try { sequence = RouteStopSequence.requireValid(bus.getRoute().getId(), routeStops.findByRoute_IdOrderByStopOrder(bus.getRoute().getId())); }
        catch (IllegalStateException ex) { throw ApiException.conflict("Invalid bus route ordering: " + ex.getMessage()); }
        int start = RouteStopSequence.indexOf(sequence, from.getId());
        int end = RouteStopSequence.indexOf(sequence, to.getId());
        if (start < 0 || end < 0) throw ApiException.badRequest("Boarding and destination stops must both be on the bus route");
        if (start >= end) throw ApiException.badRequest("Boarding stop must precede destination stop");

        List<OccupancyCalculator.Journey> journeys = new ArrayList<>();
        for (Ticket ticket : tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc(bus.getId(), request.tripId())) {
            if (ticket.getBus() == null || !bus.getId().equals(ticket.getBus().getId()) || ticket.getBoardingStop() == null || ticket.getDestinationStop() == null)
                throw ApiException.conflict("Existing ticket data is incomplete for this trip");
            journeys.add(new OccupancyCalculator.Journey(ticket.getId(), ticket.getPassengerCount(),
                    RouteStopSequence.indexOf(sequence, ticket.getBoardingStop().getId()),
                    RouteStopSequence.indexOf(sequence, ticket.getDestinationStop().getId())));
        }
        for (PassengerBooking booking : bookings.findByBus_IdAndTripIdAndStatus(bus.getId(), request.tripId(), CONFIRMED)) {
            if (booking.getBus() == null || !bus.getId().equals(booking.getBus().getId()) || booking.getBoardingStop() == null || booking.getDestinationStop() == null)
                throw ApiException.conflict("Existing booking data is incomplete for this trip");
            journeys.add(new OccupancyCalculator.Journey(booking.getId(), booking.getPassengerCount(),
                    RouteStopSequence.indexOf(sequence, booking.getBoardingStop().getId()),
                    RouteStopSequence.indexOf(sequence, booking.getDestinationStop().getId())));
        }
        String bookingId = UUID.randomUUID().toString();
        String reference = "ATM-" + bookingId.substring(0, 12).toUpperCase();
        journeys.add(new OccupancyCalculator.Journey(bookingId, request.passengerCount(), start, end));
        try {
            for (int order = 0; order < sequence.size(); order++)
                calculator.atStop(journeys, order, sequence.size(), bus.getTotalPassengerCapacity());
        } catch (IllegalArgumentException | IllegalStateException ex) {
            throw ApiException.conflict(ex.getMessage());
        }
        PassengerBooking saved = bookings.save(new PassengerBooking(bookingId, reference, request.idempotencyKey(),
                request.tripId(), bus, from, to, request.passengerCount(), CONFIRMED, Instant.now()));
        return receipt(saved);
    }

    private BookingReceipt retryReceipt(PassengerBooking prior, PassengerBookingRequest request) {
        if (!prior.getTripId().equals(request.tripId()) || !prior.getBus().getId().equals(request.busId())
                || !prior.getBoardingStop().getId().equals(request.boardingStopId())
                || !prior.getDestinationStop().getId().equals(request.destinationStopId())
                || prior.getPassengerCount() != request.passengerCount()) {
            throw ApiException.conflict("Booking idempotency key was already used for a different request");
        }
        return receipt(prior);
    }

    private BookingReceipt receipt(PassengerBooking booking) {
        return new BookingReceipt(booking.getBookingReference(), booking.getId(), booking.getTripId(), booking.getBus().getId(),
                booking.getBoardingStop().getId(), booking.getBoardingStop().getName(),
                booking.getDestinationStop().getId(), booking.getDestinationStop().getName(), booking.getPassengerCount(),
                booking.getStatus(), "SIMULATED", "NOT_BOARDING_EVIDENCE", booking.getCreatedAt());
    }

    public record BookingReceipt(String bookingReference, String bookingId, String tripId, String busId,
                                 String boardingStopId, String boardingStopName, String destinationStopId,
                                 String destinationStopName, int passengerCount, String bookingStatus,
                                 String dataOrigin, String boardingStatus, Instant createdAt) {}
}
