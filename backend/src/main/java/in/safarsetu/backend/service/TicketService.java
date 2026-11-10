package in.safarsetu.backend.service;

import in.safarsetu.backend.dto.TicketRequest;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;

@Service
public class TicketService {
    private final TicketRepository tickets;private final BusRepository buses;private final StopRepository stops;private final RouteStopRepository routeStops;private final PassengerBookingRepository bookings;
    private final OccupancyCalculator calculator=new OccupancyCalculator();
    @Autowired
    public TicketService(TicketRepository tickets,BusRepository buses,StopRepository stops,RouteStopRepository routeStops,PassengerBookingRepository bookings){this.tickets=tickets;this.buses=buses;this.stops=stops;this.routeStops=routeStops;this.bookings=bookings;}
    /** Compatibility constructor for focused legacy unit tests; Spring uses the full constructor. */
    TicketService(TicketRepository tickets,BusRepository buses,StopRepository stops,RouteStopRepository routeStops){this(tickets,buses,stops,routeStops,null);}
    @Transactional
    public TicketReceipt ingest(TicketRequest request){
        if(request==null||request.boardedAt()==null)throw ApiException.badRequest("Ticket timestamp is required");
        if(request.tripId()==null||request.tripId().isBlank()||request.tripId().length()>64)throw ApiException.badRequest("Trip identifier must be present and no longer than 64 characters");
        if(tickets.existsById(request.ticketId())||tickets.existsByIdempotencyKey(request.idempotencyKey()))throw ApiException.conflict("Ticket or idempotency key has already been ingested");
        Bus bus=buses.findByIdForUpdate(request.busId()).orElseThrow(()->ApiException.notFound("Bus not found: "+request.busId()));
        if(bus.getDataOrigin()!=DataOrigin.SIMULATED)throw ApiException.conflict("Simulated ticket events require a SIMULATED bus");
        if(bus.getRoute()==null||bus.getSeatingCapacity()<=0||(bus.getTotalPassengerCapacity()!=null&&bus.getTotalPassengerCapacity()<bus.getSeatingCapacity()))
            throw ApiException.conflict("Bus route or capacity configuration is invalid");
        Stop from=stops.findById(request.boardingStopId()).orElseThrow(()->ApiException.notFound("Boarding stop not found: "+request.boardingStopId()));
        Stop to=stops.findById(request.destinationStopId()).orElseThrow(()->ApiException.notFound("Destination stop not found: "+request.destinationStopId()));
        List<RouteStop> sequence;
        try { sequence=RouteStopSequence.requireValid(bus.getRoute().getId(),routeStops.findByRoute_IdOrderByStopOrder(bus.getRoute().getId())); }
        catch(IllegalStateException ex){throw ApiException.conflict("Invalid bus route ordering: "+ex.getMessage());}
        int a=indexOf(sequence,from.getId()),b=indexOf(sequence,to.getId());
        if(a<0||b<0)throw ApiException.badRequest("Boarding and destination stops must both be on the bus route");
        if(a>=b)throw ApiException.badRequest("Boarding stop must precede destination stop");
        if(request.boardedAt().isAfter(Instant.now().plusSeconds(60)))throw ApiException.badRequest("Ticket timestamp cannot be in the future");
        PassengerBooking linkedBooking=null;
        if(request.bookingReference()!=null&&!request.bookingReference().isBlank()){
            if(bookings==null)throw ApiException.conflict("Booking linkage is unavailable");
            linkedBooking=bookings.findByBookingReference(request.bookingReference().trim())
                    .orElseThrow(()->ApiException.notFound("Passenger booking not found: "+request.bookingReference()));
            if(!"CONFIRMED_SIMULATION".equals(linkedBooking.getStatus()))throw ApiException.conflict("Only a confirmed simulation booking can be linked to a ticket event");
            if(linkedBooking.getBus()==null||!bus.getId().equals(linkedBooking.getBus().getId())
                    ||!request.tripId().equals(linkedBooking.getTripId())
                    ||linkedBooking.getBoardingStop()==null||!from.getId().equals(linkedBooking.getBoardingStop().getId())
                    ||linkedBooking.getDestinationStop()==null||!to.getId().equals(linkedBooking.getDestinationStop().getId())
                    ||linkedBooking.getPassengerCount()!=request.passengerCount())
                throw ApiException.conflict("Ticket journey and quantity must match the linked passenger booking");
        }
        List<Ticket> existing=tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc(bus.getId(),request.tripId());
        if(existing==null)throw ApiException.conflict("Ticket repository returned no result set");
        List<OccupancyCalculator.Journey> journeys=new java.util.ArrayList<>();
        for(Ticket ticket:existing){
            if(ticket==null||ticket.getBus()==null||!bus.getId().equals(ticket.getBus().getId())||ticket.getBoardingStop()==null||ticket.getDestinationStop()==null||!request.tripId().equals(ticket.getTripId()))
                throw ApiException.conflict("Existing ticket data is incomplete or belongs to a different bus or trip");
            journeys.add(new OccupancyCalculator.Journey(ticket.getId(),ticket.getPassengerCount(),indexOf(sequence,ticket.getBoardingStop().getId()),indexOf(sequence,ticket.getDestinationStop().getId())));
        }
        if(bookings!=null){for(PassengerBooking booking:bookings.findByBus_IdAndTripIdAndStatus(bus.getId(),request.tripId(),"CONFIRMED_SIMULATION")){
            if(linkedBooking!=null&&linkedBooking.getId().equals(booking.getId()))continue;
            if(booking==null||booking.getBus()==null||!bus.getId().equals(booking.getBus().getId())||booking.getBoardingStop()==null||booking.getDestinationStop()==null)
                throw ApiException.conflict("Existing booking data is incomplete or belongs to a different bus or trip");
            journeys.add(new OccupancyCalculator.Journey(booking.getId(),booking.getPassengerCount(),indexOf(sequence,booking.getBoardingStop().getId()),indexOf(sequence,booking.getDestinationStop().getId())));
        }}
        journeys.add(new OccupancyCalculator.Journey(request.ticketId(),request.passengerCount(),a,b));
        try{for(int i=0;i<sequence.size();i++)calculator.atStop(journeys,i,sequence.size(),bus.getTotalPassengerCapacity());}
        catch(IllegalArgumentException|IllegalStateException ex){throw ApiException.conflict(ex.getMessage());}
        Ticket ticket=tickets.save(new Ticket(request.ticketId(),request.idempotencyKey(),bus,from,to,request.passengerCount(),request.boardedAt(),DataOrigin.SIMULATED,request.tripId(),linkedBooking));
        if(linkedBooking!=null){linkedBooking.markSimulatedBoardingRecorded();bookings.save(linkedBooking);}
        return new TicketReceipt(ticket.getId(),ticket.getBus().getId(),ticket.getTripId(),ticket.getPassengerCount(),ticket.getBoardedAt(),"SIMULATED","ACCEPTED",linkedBooking==null?null:linkedBooking.getBookingReference(),linkedBooking==null?null:linkedBooking.getStatus());
    }
    private int indexOf(List<RouteStop> sequence,String stopId){return RouteStopSequence.indexOf(sequence,stopId);}
    public record TicketReceipt(String ticketId,String busId,String tripId,int passengerCount,Instant boardedAt,String dataOrigin,String eventStatus,String bookingReference,String bookingStatus){
        public TicketReceipt(String ticketId,String busId,String tripId,int passengerCount,Instant boardedAt,String dataOrigin,String eventStatus){this(ticketId,busId,tripId,passengerCount,boardedAt,dataOrigin,eventStatus,null,null);}
    }
}


