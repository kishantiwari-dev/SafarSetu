package in.safarsetu.backend.service;
import in.safarsetu.backend.dto.*;
import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.repository.*;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class SimulatedArrivalServiceTest {
 private final SimulatedTripArrivalRepository arrivals=mock(SimulatedTripArrivalRepository.class);
 private final BusRepository buses=mock(BusRepository.class); private final StopRepository stops=mock(StopRepository.class);
 private final RouteStopRepository routeStops=mock(RouteStopRepository.class); private final TicketRepository tickets=mock(TicketRepository.class); private final BusService busService=mock(BusService.class);
 private final SimulatedArrivalService service=new SimulatedArrivalService(arrivals,buses,stops,routeStops,tickets,busService);
 private final Route route=new Route("r1","route",DataOrigin.SIMULATED,true);
 private final Bus bus=new Bus("b1","fleet",20,30,route,DataOrigin.SIMULATED,true);
 private final Stop a=new Stop("s1","A",28,77,VerificationStatus.APPROXIMATE), b=new Stop("s2","B",28,77,VerificationStatus.APPROXIMATE), c=new Stop("s3","C",28,77,VerificationStatus.APPROXIMATE);
 private SimulatedArrivalRequest request(String event,String stop,String at){return new SimulatedArrivalRequest(event,"trip-1","b1",stop,Instant.parse(at));}
 private void setup(){when(buses.findByIdForUpdate("b1")).thenReturn(Optional.of(bus));when(stops.findById(anyString())).thenAnswer(i->Map.of("s1",a,"s2",b,"s3",c).containsKey(i.getArgument(0))?Optional.of(Map.of("s1",a,"s2",b,"s3",c).get(i.getArgument(0))):Optional.empty());when(routeStops.findByRoute_IdOrderByStopOrder("r1")).thenReturn(List.of(new RouteStop(route,a,0),new RouteStop(route,b,1),new RouteStop(route,c,2)));when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of());when(arrivals.save(any())).thenAnswer(i->i.getArgument(0));when(busService.occupancy("b1","s2","trip-1")).thenReturn(null);}
 @Test void acceptsArrivalLabelsSimulatedAlightingAndReturnsOccupancyProjection(){setup();Ticket t=new Ticket("t","k",bus,a,b,3,Instant.parse("2026-10-25T19:00:00Z"),DataOrigin.SIMULATED,"trip-1");when(tickets.findByBus_IdAndTripIdOrderByBoardedAtAsc("b1","trip-1")).thenReturn(List.of(t));var receipt=service.arrive(request("ev1","s2","2026-10-25T20:00:00Z"));assertEquals("SIMULATED",receipt.dataOrigin());assertEquals("ACCEPTED",receipt.eventStatus());assertEquals("SIMULATED_EXPECTED_ALIGHTING",receipt.alightingMeaning());assertEquals(3,receipt.simulatedAlightingPassengers());verify(busService).occupancy("b1","s2","trip-1");verify(arrivals).save(any(SimulatedTripArrival.class));}
 @Test void rejectsDuplicateEventId(){setup();when(arrivals.existsById("ev1")).thenReturn(true);assertEquals(409,assertThrows(ApiException.class,()->service.arrive(request("ev1","s1","2026-10-25T20:00:00Z"))).getStatus().value());verify(arrivals,never()).save(any());}
 @Test void rejectsArrivalMovingBackwards(){setup();when(arrivals.findTopByBus_IdAndTripIdOrderByStopOrderDesc("b1","trip-1")).thenReturn(Optional.of(new SimulatedTripArrival("old",bus,b,"trip-1",1,Instant.parse("2026-10-25T20:00:00Z"),0)));assertEquals(409,assertThrows(ApiException.class,()->service.arrive(request("ev2","s1","2026-10-25T20:01:00Z"))).getStatus().value());verify(arrivals,never()).save(any());}
 @Test void rejectsRepeatedStopAndEarlierTimestamp(){setup();when(arrivals.findTopByBus_IdAndTripIdOrderByStopOrderDesc("b1","trip-1")).thenReturn(Optional.of(new SimulatedTripArrival("old",bus,b,"trip-1",1,Instant.parse("2026-10-25T20:00:00Z"),0)));assertEquals(409,assertThrows(ApiException.class,()->service.arrive(request("ev2","s2","2026-10-25T20:00:00Z"))).getStatus().value());}
 @Test void rejectsStopOutsideRoute(){setup();Stop other=new Stop("other","Other",28,77,VerificationStatus.APPROXIMATE);when(stops.findById("other")).thenReturn(Optional.of(other));assertEquals(400,assertThrows(ApiException.class,()->service.arrive(request("ev1","other","2026-10-25T20:00:00Z"))).getStatus().value());}
}


