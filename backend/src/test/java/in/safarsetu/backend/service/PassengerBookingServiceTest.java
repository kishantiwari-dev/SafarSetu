package in.safarsetu.backend.service;

import in.safarsetu.backend.dto.PassengerBookingRequest;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class PassengerBookingServiceTest {
    private final PassengerBookingRepository bookings = mock(PassengerBookingRepository.class);
    private final TicketRepository tickets = mock(TicketRepository.class);
    private final BusRepository buses = mock(BusRepository.class);
    private final StopRepository stops = mock(StopRepository.class);
    private final RouteStopRepository routeStops = mock(RouteStopRepository.class);
    private final PassengerBookingService service = new PassengerBookingService(bookings, tickets, buses, stops, routeStops);
    private final Route route = new Route("r1", "Route 1", DataOrigin.SIMULATED, true);
    private final Bus bus = new Bus("b1", "FLEET-1", 8, 10, route, DataOrigin.SIMULATED, true);
    private final Stop a = new Stop("s1", "A", 28, 77, VerificationStatus.APPROXIMATE);
    private final Stop b = new Stop("s2", "B", 28, 77, VerificationStatus.APPROXIMATE);
    private final Stop c = new Stop("s3", "C", 28, 77, VerificationStatus.APPROXIMATE);

    @BeforeEach void setUp() {
        when(bookings.findByIdempotencyKey("key-1")).thenReturn(Optional.empty());
        when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));
        when(stops.findById("s1")).thenReturn(Optional.of(a));
        when(stops.findById("s2")).thenReturn(Optional.of(b));
        when(stops.findById("s3")).thenReturn(Optional.of(c));
        when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route, a, 0), new RouteStop(route, b, 1), new RouteStop(route, c, 2)));
        when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1", "SIM-TRIP-b1-DEMO-01")).thenReturn(List.of());
        when(bookings.findByBus_IdAndTripIdAndStatus("b1", "SIM-TRIP-b1-DEMO-01", "CONFIRMED_SIMULATION")).thenReturn(List.of());
        when(bookings.save(any(PassengerBooking.class))).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test void createsQuantityBookingAndLabelsItAsNotBoardingEvidence() {
        var receipt = service.create(request("s1", "s3", 3));
        assertEquals("SIMULATED", receipt.dataOrigin());
        assertEquals("NOT_BOARDING_EVIDENCE", receipt.boardingStatus());
        assertEquals(3, receipt.passengerCount());
        assertTrue(receipt.bookingReference().startsWith("ATM-"));
        verify(bookings).save(any(PassengerBooking.class));
    }

    @Test void duplicateRequestReturnsTheOriginalReceiptWithoutSavingAgain() {
        var existing = new PassengerBooking("id-1", "ATM-REFERENCE", "key-1", "SIM-TRIP-b1-DEMO-01", bus, a, c, 3,
                "CONFIRMED_SIMULATION", Instant.parse("2026-10-01T10:00:00Z"));
        when(bookings.findByIdempotencyKey("key-1")).thenReturn(Optional.of(existing));
        var receipt = service.create(request("s1", "s3", 3));
        assertEquals("ATM-REFERENCE", receipt.bookingReference());
        verify(bookings, never()).save(any());
    }

    @Test void sameIdempotencyKeyWithDifferentQuantityConflicts() {
        var existing = new PassengerBooking("id-1", "ATM-REFERENCE", "key-1", "SIM-TRIP-b1-DEMO-01", bus, a, c, 3,
                "CONFIRMED_SIMULATION", Instant.parse("2026-10-01T10:00:00Z"));
        when(bookings.findByIdempotencyKey("key-1")).thenReturn(Optional.of(existing));
        assertEquals(409, assertThrows(ApiException.class, () -> service.create(request("s1", "s3", 4))).getStatus().value());
    }

    @Test void bookingCapacityCountsPreviouslyBoardedTicketPassengers() {
        when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1", "SIM-TRIP-b1-DEMO-01")).thenReturn(List.of(
                new Ticket("ticket", "ticket-key", bus, a, c, 6, Instant.now(), DataOrigin.SIMULATED, "SIM-TRIP-b1-DEMO-01")));
        assertEquals(409, assertThrows(ApiException.class, () -> service.create(request("s1", "s3", 5))).getStatus().value());
        verify(bookings, never()).save(any());
    }

    @Test void bookingCapacityCountsExistingReservationsOnOverlappingSegmentsOnly() {
        var existing = new PassengerBooking("other", "ATM-OTHER", "other-key", "SIM-TRIP-b1-DEMO-01", bus, a, b, 8,
                "CONFIRMED_SIMULATION", Instant.now());
        when(bookings.findByBus_IdAndTripIdAndStatus("b1", "SIM-TRIP-b1-DEMO-01", "CONFIRMED_SIMULATION")).thenReturn(List.of(existing));
        assertEquals(409, assertThrows(ApiException.class, () -> service.create(request("s1", "s2", 3))).getStatus().value());
        verify(bookings, never()).save(any());
    }

    @Test void laterSegmentCanReuseCapacityAfterExistingReservationAlights() {
        var existing = new PassengerBooking("other", "ATM-OTHER", "other-key", "SIM-TRIP-b1-DEMO-01", bus, a, b, 8,
                "CONFIRMED_SIMULATION", Instant.now());
        when(bookings.findByBus_IdAndTripIdAndStatus("b1", "SIM-TRIP-b1-DEMO-01", "CONFIRMED_SIMULATION")).thenReturn(List.of(existing));
        var receipt = service.create(request("s2", "s3", 8));
        assertEquals(8, receipt.passengerCount());
        verify(bookings).save(any(PassengerBooking.class));
    }

    @Test void rejectsUnrecognizedTripContextInsteadOfInventingAServiceRun() {
        var invalidRun = new PassengerBookingRequest("key-1", "real-looking-run", "b1", "s1", "s3", 1);
        assertEquals(400, assertThrows(ApiException.class, () -> service.create(invalidRun)).getStatus().value());
        verify(bookings, never()).save(any());
    }

    private PassengerBookingRequest request(String from, String to, int count) {
        return new PassengerBookingRequest("key-1", "SIM-TRIP-b1-DEMO-01", "b1", from, to, count);
    }
}
