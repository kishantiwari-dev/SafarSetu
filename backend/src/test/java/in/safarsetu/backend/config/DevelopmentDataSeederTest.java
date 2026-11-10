package in.safarsetu.backend.config;

import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.repository.*;
import org.junit.jupiter.api.Test;

import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class DevelopmentDataSeederTest {
    @Test
    void seedHasValidRouteTicketAndLocationRelationshipsAndIsRepeatable() {
        var data = new InMemoryRepositories();
        var seeder = new DevelopmentDataSeeder();

        seed(seeder, data);
        assertSeedIntegrity(data);
        seed(seeder, data);

        assertEquals(22, data.stops.size());
        assertEquals(9, data.routes.size());
        assertEquals(52, data.routeStops.size());
        assertEquals(13, data.buses.size());
        assertEquals(23, data.tickets.size());
        assertEquals(22, data.locations.size());
        assertEquals(13, data.snapshots.size());
        assertSeedIntegrity(data);
        verify(data.stopRepository, times(22)).save(any(Stop.class));
        verify(data.routeRepository, times(9)).save(any(Route.class));
        verify(data.routeStopRepository, times(52)).save(any(RouteStop.class));
        verify(data.busRepository, times(13)).save(any(Bus.class));
        verify(data.ticketRepository, times(23)).save(any(Ticket.class));
        verify(data.locationRepository, times(22)).save(any(BusLocation.class));
        verify(data.snapshotRepository, times(13)).save(any(OccupancySnapshot.class));
    }

    private static void seed(DevelopmentDataSeeder seeder, InMemoryRepositories data) {
        seeder.seedData(data.stopRepository, data.routeRepository, data.routeStopRepository,
                data.busRepository, data.ticketRepository, data.locationRepository,
                data.snapshotRepository);
    }

    private static void assertSeedIntegrity(InMemoryRepositories data) {
        assertEquals(22, data.stops.size());
        assertEquals(9, data.routes.size());
        assertEquals(52, data.routeStops.size());
        assertEquals(13, data.buses.size());
        assertEquals(23, data.tickets.size());
        assertEquals(22, data.locations.size());
        assertEquals(13, data.snapshots.size());

        for (var route : data.routes.values()) {
            var stops = data.routeStopsByRoute.get(route.getId());
            assertNotNull(stops);
            assertTrue(stops.size() >= 2);
            var orders = new HashSet<Integer>();
            var stopIds = new HashSet<String>();
            for (var routeStop : stops) {
                assertSame(route, routeStop.getRoute());
                assertTrue(routeStop.getStopOrder() >= 0);
                assertTrue(orders.add(routeStop.getStopOrder()), "duplicate order on " + route.getId());
                assertTrue(stopIds.add(routeStop.getStop().getId()), "duplicate stop on " + route.getId());
            }
            assertEquals(stops.size(), orders.size());
            for (int index = 0; index < stops.size(); index++) {
                assertEquals(index, stops.get(index).getStopOrder(), "non-contiguous route order on " + route.getId());
            }
        }

        assertEquals(List.of("BOTANICAL_GARDEN", "SECTOR_18", "SECTOR_62", "KP_II", "PARI_CHOWK", "ALPHA_1"),
                data.routeStopsByRoute.get("SIM-GN-001").stream().map(rs -> rs.getStop().getId()).toList());
        assertEquals(List.of("ALPHA_1", "PARI_CHOWK", "KP_II", "SECTOR_62", "SECTOR_18", "BOTANICAL_GARDEN"),
                data.routeStopsByRoute.get("SIM-GN-009").stream().map(rs -> rs.getStop().getId()).toList());
        assertTrue(List.of("BUS-SIM-001", "BUS-SIM-009", "BUS-SIM-010").stream()
                .allMatch(id -> data.buses.get(id).getRoute().getId().equals("SIM-GN-001")));
        assertTrue(List.of("BUS-SIM-011", "BUS-SIM-012", "BUS-SIM-013").stream()
                .allMatch(id -> data.buses.get(id).getRoute().getId().equals("SIM-GN-009")));

        // A stable stop can be shared by distinct routes; ordering belongs to RouteStop.
        assertTrue(data.routeStopsByRoute.get("SIM-GN-002").stream()
                .anyMatch(rs -> rs.getStop().getId().equals("SECTOR_51")));
        assertTrue(data.routeStopsByRoute.get("SIM-GN-003").stream()
                .anyMatch(rs -> rs.getStop().getId().equals("SECTOR_51")));

        var ticketIds = new HashSet<String>();
        var idempotencyKeys = new HashSet<String>();
        for (var ticket : data.tickets.values()) {
            assertTrue(ticketIds.add(ticket.getId()));
            assertTrue(idempotencyKeys.add(ticket.getIdempotencyKey()));
            assertTrue(ticket.getPassengerCount() > 0);
            assertNotNull(ticket.getBoardedAt());
            assertEquals("SIM-TRIP-" + ticket.getBus().getId() + "-DEMO-01", ticket.getTripId());
            assertEquals(DataOrigin.SIMULATED, ticket.getDataOrigin());

            var routeStops = data.routeStopsByRoute.get(ticket.getBus().getRoute().getId());
            int boardingOrder = orderOf(routeStops, ticket.getBoardingStop().getId());
            int destinationOrder = orderOf(routeStops, ticket.getDestinationStop().getId());
            assertTrue(boardingOrder >= 0, "boarding stop belongs to bus route");
            assertTrue(destinationOrder > boardingOrder, "destination follows boarding stop");
        }
        for (var busId : data.buses.keySet()) {
            var times = data.tickets.values().stream().filter(ticket -> ticket.getBus().getId().equals(busId))
                    .map(Ticket::getBoardedAt).toList();
            assertEquals(times.stream().sorted().toList(), times, "ticket event times ordered for " + busId);
        }

        var busesWithoutTickets = data.buses.keySet().stream()
                .filter(busId -> data.tickets.values().stream().noneMatch(ticket -> ticket.getBus().getId().equals(busId)))
                .toList();
        assertEquals(List.of("BUS-SIM-005"), busesWithoutTickets);
        assertEquals(DataQuality.NO_TICKET_DATA, data.snapshots.get("SNAP-BUS-SIM-005").getDataQuality());
        assertEquals(32, data.snapshots.get("SNAP-BUS-SIM-009").getEstimatedOnboard());
        assertEquals(48, data.snapshots.get("SNAP-BUS-SIM-010").getEstimatedOnboard());
        assertEquals(18, data.snapshots.get("SNAP-BUS-SIM-011").getEstimatedOnboard());

        for (var bus : data.buses.values()) {
            assertTrue(bus.getSeatingCapacity() > 0);
            assertEquals(DataOrigin.SIMULATED, bus.getDataOrigin());
        }

        for (var location : data.locations.values()) {
            assertNotNull(location.getBus());
            assertTrue(location.getLatitude() >= -90 && location.getLatitude() <= 90);
            assertTrue(location.getLongitude() >= -180 && location.getLongitude() <= 180);
            assertNotNull(location.getRecordedAt());
            assertEquals(DataOrigin.SIMULATED, location.getDataOrigin());
        }
        for (var busId : data.buses.keySet()) {
            var times = data.locations.values().stream().filter(location -> location.getBus().getId().equals(busId))
                    .map(BusLocation::getRecordedAt).toList();
            assertEquals(times.stream().sorted().toList(), times, "GPS track times ordered for " + busId);
        }
    }

    private static int orderOf(List<RouteStop> routeStops, String stopId) {
        return routeStops.stream().filter(rs -> rs.getStop().getId().equals(stopId))
                .mapToInt(RouteStop::getStopOrder).findFirst().orElse(-1);
    }

    /** Repository-backed in-memory fixture checks; this does not test PostgreSQL constraints. */
    private static final class InMemoryRepositories {
        final Map<String, Stop> stops = new LinkedHashMap<>();
        final Map<String, Route> routes = new LinkedHashMap<>();
        final Map<RouteStopId, RouteStop> routeStops = new LinkedHashMap<>();
        final Map<String, List<RouteStop>> routeStopsByRoute = new HashMap<>();
        final Map<String, Bus> buses = new LinkedHashMap<>();
        final Map<String, Ticket> tickets = new LinkedHashMap<>();
        final Map<String, BusLocation> locations = new LinkedHashMap<>();
        final Map<String, OccupancySnapshot> snapshots = new LinkedHashMap<>();

        final StopRepository stopRepository = mock(StopRepository.class);
        final RouteRepository routeRepository = mock(RouteRepository.class);
        final RouteStopRepository routeStopRepository = mock(RouteStopRepository.class);
        final BusRepository busRepository = mock(BusRepository.class);
        final TicketRepository ticketRepository = mock(TicketRepository.class);
        final BusLocationRepository locationRepository = mock(BusLocationRepository.class);
        final OccupancySnapshotRepository snapshotRepository = mock(OccupancySnapshotRepository.class);

        InMemoryRepositories() {
            when(stopRepository.findById(anyString())).thenAnswer(i -> Optional.ofNullable(stops.get(i.getArgument(0))));
            when(stopRepository.save(any(Stop.class))).thenAnswer(i -> { var row=(Stop)i.getArgument(0); stops.put(row.getId(), row); return row; });

            when(routeRepository.findById(anyString())).thenAnswer(i -> Optional.ofNullable(routes.get(i.getArgument(0))));
            when(routeRepository.save(any(Route.class))).thenAnswer(i -> { var row=(Route)i.getArgument(0); routes.put(row.getId(), row); return row; });

            when(routeStopRepository.existsById(any(RouteStopId.class))).thenAnswer(i -> routeStops.containsKey(i.getArgument(0)));
            when(routeStopRepository.save(any(RouteStop.class))).thenAnswer(i -> {
                var row=(RouteStop)i.getArgument(0);
                var key=new RouteStopId(row.getRoute().getId(), row.getStop().getId());
                routeStops.put(key, row);
                var ordered=routeStopsByRoute.computeIfAbsent(row.getRoute().getId(), ignored -> new ArrayList<>());
                if (!ordered.contains(row)) { ordered.add(row); ordered.sort(Comparator.comparingInt(RouteStop::getStopOrder)); }
                return row;
            });
            when(routeStopRepository.findByRoute_IdOrderByStopOrder(anyString()))
                    .thenAnswer(i -> routeStopsByRoute.getOrDefault(i.getArgument(0), List.of()));

            when(busRepository.findById(anyString())).thenAnswer(i -> Optional.ofNullable(buses.get(i.getArgument(0))));
            when(busRepository.save(any(Bus.class))).thenAnswer(i -> { var row=(Bus)i.getArgument(0); buses.put(row.getId(), row); return row; });

            when(ticketRepository.existsById(anyString())).thenAnswer(i -> tickets.containsKey(i.getArgument(0)));
            when(ticketRepository.save(any(Ticket.class))).thenAnswer(i -> { var row=(Ticket)i.getArgument(0); tickets.put(row.getId(), row); return row; });

            when(locationRepository.existsById(anyString())).thenAnswer(i -> locations.containsKey(i.getArgument(0)));
            when(locationRepository.save(any(BusLocation.class))).thenAnswer(i -> { var row=(BusLocation)i.getArgument(0); locations.put(row.getId(), row); return row; });

            when(snapshotRepository.existsById(anyString())).thenAnswer(i -> snapshots.containsKey(i.getArgument(0)));
            when(snapshotRepository.save(any(OccupancySnapshot.class))).thenAnswer(i -> { var row=(OccupancySnapshot)i.getArgument(0); snapshots.put(row.getId(), row); return row; });
        }
    }
}
