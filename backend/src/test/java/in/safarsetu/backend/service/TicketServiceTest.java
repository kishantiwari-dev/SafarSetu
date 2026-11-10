package in.safarsetu.backend.service;

import in.safarsetu.backend.dto.TicketRequest;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class TicketServiceTest {
    private final TicketRepository tickets=mock(TicketRepository.class);
    private final BusRepository buses=mock(BusRepository.class);
    private final StopRepository stops=mock(StopRepository.class);
    private final RouteStopRepository routeStops=mock(RouteStopRepository.class);
    private final PassengerBookingRepository bookings=mock(PassengerBookingRepository.class);
    private final TicketService service=new TicketService(tickets,buses,stops,routeStops,bookings);
    @Test void duplicateIdempotencyKeyIsRejectedWithoutSaving(){
        when(tickets.existsById("t1")).thenReturn(false);when(tickets.existsByIdempotencyKey("key1")).thenReturn(true);
        var request=new TicketRequest("t1","key1","b1","s1","s2",2,Instant.parse("2026-10-11T06:00:00Z"),"trip-1");
        assertEquals(409,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());verify(tickets,never()).save(any());
    }
    @Test void duplicateTicketIdIsRejectedWithoutSaving(){
        when(tickets.existsById("t1")).thenReturn(true);when(tickets.existsByIdempotencyKey("key2")).thenReturn(false);
        var request=new TicketRequest("t1","key2","b1","s1","s2",2,Instant.parse("2026-10-11T06:00:00Z"),"trip-1");
        assertEquals(409,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());verify(tickets,never()).save(any());
    }
    @Test void rejectsBoardingAfterDestination(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s1")).thenReturn(Optional.of(a));when(stops.findById("s2")).thenReturn(Optional.of(b));
        when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,b,0),new RouteStop(route,a,1)));
        var request=new TicketRequest("t1","key1","b1","s1","s2",2,Instant.parse("2026-10-11T06:00:00Z"),"trip-1");
        assertEquals(400,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());verify(tickets,never()).save(any());
    }
    @Test void rejectsStopsThatDoNotBelongToAssignedBusRoute(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE);
        Stop routeStopA=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE),routeStopB=new Stop("s4","D",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s1")).thenReturn(Optional.of(a));when(stops.findById("s2")).thenReturn(Optional.of(b));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,routeStopA,0),new RouteStop(route,routeStopB,1)));
        var request=new TicketRequest("t1","key1","b1","s1","s2",2,Instant.parse("2026-10-11T06:00:00Z"),"trip-1");
        assertEquals(400,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());verify(tickets,never()).save(any());
    }
    @Test void rejectsNewTicketThatWouldExceedPassengerCapacity(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE),c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s2")).thenReturn(Optional.of(b));when(stops.findById("s3")).thenReturn(Optional.of(c));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));
        Ticket existing=new Ticket("old","old-key",bus,a,c,10,Instant.parse("2026-10-11T06:00:00Z"),DataOrigin.SIMULATED,"trip-1");when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of(existing));
        var request=new TicketRequest("t1","key1","b1","s2","s3",6,Instant.parse("2026-10-11T06:01:00Z"),"trip-1");
        assertEquals(409,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());verify(tickets,never()).save(any());
    }
    @Test void capacityValidationIsLimitedToTheRequestedTrip(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE),c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s2")).thenReturn(Optional.of(b));when(stops.findById("s3")).thenReturn(Optional.of(c));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));
        when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of());
        var request=new TicketRequest("t1","key1","b1","s2","s3",6,Instant.parse("2026-10-11T06:01:00Z"),"trip-1");
        when(tickets.save(any(Ticket.class))).thenAnswer(invocation->invocation.getArgument(0));

        var receipt=service.ingest(request);

        assertEquals("trip-1",receipt.tripId());
        verify(tickets).findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1");
        verify(tickets).save(argThat(ticket->"trip-1".equals(ticket.getTripId())));
        verify(tickets,never()).findByBus_IdOrderByBoardedAtAsc("b1");
    }

    @Test void ticketIngestionCountsConfirmedBookingReservationsForCapacity(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE),c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s2")).thenReturn(Optional.of(b));when(stops.findById("s3")).thenReturn(Optional.of(c));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));
        when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of());
        var booking=new PassengerBooking("booking-1","ATM-1","booking-key","trip-1",bus,a,c,10,"CONFIRMED_SIMULATION",Instant.now());
        when(bookings.findByBus_IdAndTripIdAndStatus("b1","trip-1","CONFIRMED_SIMULATION")).thenReturn(List.of(booking));
        var request=new TicketRequest("ticket-2","ticket-key","b1","s2","s3",6,Instant.parse("2026-10-11T06:01:00Z"),"trip-1");
        assertEquals(409,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());
        verify(tickets,never()).save(any());
    }

    @Test void linkedTicketMovesReservationOutOfReservedCapacityWithoutDoubleCounting(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE),c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s1")).thenReturn(Optional.of(a));when(stops.findById("s3")).thenReturn(Optional.of(c));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));
        when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of());
        var booking=new PassengerBooking("booking-1","ATM-1","booking-key","trip-1",bus,a,c,10,"CONFIRMED_SIMULATION",Instant.now());
        when(bookings.findByBookingReference("ATM-1")).thenReturn(Optional.of(booking));
        when(bookings.findByBus_IdAndTripIdAndStatus("b1","trip-1","CONFIRMED_SIMULATION")).thenReturn(List.of(booking));
        when(tickets.save(any(Ticket.class))).thenAnswer(invocation->invocation.getArgument(0));
        var request=new TicketRequest("ticket-1","ticket-key","b1","s1","s3",10,Instant.now(),"trip-1","ATM-1");

        var receipt=service.ingest(request);

        assertEquals("ATM-1",receipt.bookingReference());
        assertEquals("BOARDING_RECORDED_SIMULATION",receipt.bookingStatus());
        assertEquals("BOARDING_RECORDED_SIMULATION",booking.getStatus());
        verify(tickets).save(argThat(ticket->ticket.getBooking()!=null&&"booking-1".equals(ticket.getBooking().getId())));
        verify(bookings).save(booking);
    }

    @Test void linkedTicketMustExactlyMatchBookingJourneyAndQuantity(){
        Route route=new Route("r1","r",DataOrigin.SIMULATED,true);Bus bus=new Bus("b1","fleet",10,15,route,DataOrigin.SIMULATED,true);Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE),b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE),c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
        when(tickets.existsById(anyString())).thenReturn(false);when(tickets.existsByIdempotencyKey(anyString())).thenReturn(false);when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById("s1")).thenReturn(Optional.of(a));when(stops.findById("s3")).thenReturn(Optional.of(c));when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));
        var booking=new PassengerBooking("booking-1","ATM-1","booking-key","trip-1",bus,a,c,4,"CONFIRMED_SIMULATION",Instant.now());
        when(bookings.findByBookingReference("ATM-1")).thenReturn(Optional.of(booking));
        var request=new TicketRequest("ticket-1","ticket-key","b1","s1","s3",5,Instant.now(),"trip-1","ATM-1");
        assertEquals(409,assertThrows(ApiException.class,()->service.ingest(request)).getStatus().value());
        verify(tickets,never()).save(any());
        verify(bookings,never()).save(any(PassengerBooking.class));
    }
}
