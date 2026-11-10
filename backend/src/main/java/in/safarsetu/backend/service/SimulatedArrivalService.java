package in.safarsetu.backend.service;
import in.safarsetu.backend.dto.SimulatedArrivalRequest;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;
@Service
public class SimulatedArrivalService {
 private final SimulatedTripArrivalRepository arrivals; private final BusRepository buses; private final StopRepository stops; private final RouteStopRepository routeStops; private final TicketRepository tickets; private final BusService busService;
 public SimulatedArrivalService(SimulatedTripArrivalRepository arrivals,BusRepository buses,StopRepository stops,RouteStopRepository routeStops,TicketRepository tickets,BusService busService){this.arrivals=arrivals;this.buses=buses;this.stops=stops;this.routeStops=routeStops;this.tickets=tickets;this.busService=busService;}
 @Transactional public ArrivalReceipt arrive(SimulatedArrivalRequest request){
  if(request==null||request.arrivedAt()==null)throw ApiException.badRequest("Arrival timestamp is required");
  if(request.eventId()==null||request.eventId().isBlank()||request.eventId().length()>64)throw ApiException.badRequest("Event identifier must be present and no longer than 64 characters");
  if(request.tripId()==null||request.tripId().isBlank()||request.tripId().length()>64)throw ApiException.badRequest("Trip identifier must be present and no longer than 64 characters");
  if(arrivals.existsById(request.eventId()))throw ApiException.conflict("Arrival event has already been accepted");
  Bus bus=buses.findByIdForUpdate(request.busId()).orElseThrow(()->ApiException.notFound("Bus not found: "+request.busId()));
  if(bus.getDataOrigin()!=DataOrigin.SIMULATED)throw ApiException.conflict("Simulated arrival events require a SIMULATED bus");
  if(request.arrivedAt().isAfter(Instant.now().plusSeconds(60)))throw ApiException.badRequest("Arrival timestamp cannot be in the future");
  List<RouteStop> sequence; try{sequence=RouteStopSequence.requireValid(bus.getRoute().getId(),routeStops.findByRoute_IdOrderByStopOrder(bus.getRoute().getId()));}catch(IllegalStateException ex){throw ApiException.conflict("Invalid bus route ordering: "+ex.getMessage());}
  Stop stop=stops.findById(request.stopId()).orElseThrow(()->ApiException.notFound("Stop not found: "+request.stopId()));
  int order=RouteStopSequence.indexOf(sequence,stop.getId()); if(order<0)throw ApiException.badRequest("Arrival stop must be on the bus route");
  var previous=arrivals.findTopByBus_IdAndTripIdOrderByStopOrderDesc(bus.getId(),request.tripId());
  if(previous.isPresent()&&(order<=previous.get().getStopOrder()||request.arrivedAt().isBefore(previous.get().getArrivedAt())))throw ApiException.conflict("Arrival must advance through the route and time");
  if(arrivals.existsByBus_IdAndTripIdAndStopOrder(bus.getId(),request.tripId(),order))throw ApiException.conflict("Arrival already exists for this trip stop");
  int alighting=0; for(Ticket ticket:tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc(bus.getId(),request.tripId())) if(ticket.getDataOrigin()==DataOrigin.SIMULATED&&ticket.getBoardedAt()!=null&&!ticket.getBoardedAt().isAfter(request.arrivedAt())&&ticket.getDestinationStop()!=null&&stop.getId().equals(ticket.getDestinationStop().getId())) alighting=Math.addExact(alighting,ticket.getPassengerCount());
  var saved=arrivals.save(new SimulatedTripArrival(request.eventId(),bus,stop,request.tripId(),order,request.arrivedAt(),alighting));
  var occupancy=busService.occupancy(bus.getId(),stop.getId(),request.tripId());
  return new ArrivalReceipt(saved.getEventId(),bus.getId(),request.tripId(),stop.getId(),order,saved.getArrivedAt(),alighting,"ACCEPTED","SIMULATED","SIMULATED_EXPECTED_ALIGHTING",occupancy);
 }
 public record ArrivalReceipt(String eventId,String busId,String tripId,String stopId,int stopOrder,Instant arrivedAt,int simulatedAlightingPassengers,String eventStatus,String dataOrigin,String alightingMeaning,in.safarsetu.backend.dto.OccupancyDto occupancy){}
}


