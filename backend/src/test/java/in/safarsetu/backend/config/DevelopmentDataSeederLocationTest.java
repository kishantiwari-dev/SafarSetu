package in.safarsetu.backend.config;

import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.repository.BusLocationRepository;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class DevelopmentDataSeederLocationTest {
    @Test
    void seedsLocationsFromTheirStableStopIdsAndIsRepeatable() {
        var stops = stops();
        var buses = buses();
        var locations = new LinkedHashMap<String, BusLocation>();
        var seeder = new DevelopmentDataSeeder();
        var repository = locationRepository(locations);

        seeder.seedLocations(repository, buses, stops);
        seeder.seedLocations(repository, buses, stops);

        assertEquals(22, locations.size());
        var first = locations.get("LOC-BUS-SIM-001-0");
        var source = stops.get("BOTANICAL_GARDEN");
        assertNotNull(first);
        assertSame(buses.get("BUS-SIM-001"), first.getBus());
        assertEquals(source.getLatitude() + .0007, first.getLatitude());
        assertEquals(source.getLongitude() + .0004, first.getLongitude());
    }

    @Test
    void reportsMissingStopReferenceInsteadOfDereferencingNull() {
        var stops = stops();
        stops.remove("SECTOR_62");
        var failure = assertThrows(IllegalStateException.class,
                () -> new DevelopmentDataSeeder().seedLocations(locationRepository(new HashMap<>()), buses(), stops));

        assertTrue(failure.getMessage().contains("missing stop 'SECTOR_62'"));
    }

    private static Map<String, Stop> stops() {
        Map<String, Stop> stops = new HashMap<>();
        put(stops, "BOTANICAL_GARDEN", 28.5647, 77.3340);
        put(stops, "SECTOR_18", 28.5708, 77.3261);
        put(stops, "SECTOR_62", 28.6270, 77.3725);
        put(stops, "SECTOR_51", 28.5834, 77.3730);
        put(stops, "SECTOR_76", 28.5678, 77.3761);
        put(stops, "GAUR_CITY", 28.6070, 77.4350);
        put(stops, "KISAN_CHOWK", 28.6130, 77.4490);
        put(stops, "GREATER_NOIDA_WEST", 28.5950, 77.4450);
        put(stops, "KASNA", 28.4070, 77.5050);
        put(stops, "SHARDA", 28.4720, 77.4830);
        put(stops, "GBU", 28.4190, 77.5300);
        put(stops, "DADRI_RAIL", 28.5525, 77.5545);
        put(stops, "ALPHA_1", 28.4712, 77.5070);
        put(stops, "KP_II", 28.4578, 77.5000);
        put(stops, "PARI_CHOWK", 28.4652, 77.5080);
        put(stops, "ALPHA_1", 28.4712, 77.5070);
        return stops;
    }

    private static void put(Map<String, Stop> stops, String id, double latitude, double longitude) {
        stops.put(id, new Stop(id, id, latitude, longitude, VerificationStatus.APPROXIMATE));
    }

    private static Map<String, Bus> buses() {
        Map<String, Bus> buses = new HashMap<>();
        for (int number : new int[]{1, 2, 3, 4, 6, 7, 8, 11, 12, 13}) {
            String id = "BUS-SIM-%03d".formatted(number);
            buses.put(id, new Bus(id, id, 40, 50, null, DataOrigin.SIMULATED, true));
        }
        return buses;
    }

    private static BusLocationRepository locationRepository(Map<String, BusLocation> locations) {
        return (BusLocationRepository) Proxy.newProxyInstance(BusLocationRepository.class.getClassLoader(),
                new Class<?>[]{BusLocationRepository.class}, (proxy, method, args) -> switch (method.getName()) {
                    case "existsById" -> locations.containsKey(args[0]);
                    case "save" -> {
                        BusLocation location = (BusLocation) args[0];
                        locations.putIfAbsent(location.getId(), location);
                        yield location;
                    }
                    case "toString" -> "InMemoryBusLocationRepository";
                    case "hashCode" -> System.identityHashCode(proxy);
                    case "equals" -> proxy == args[0];
                    default -> throw new UnsupportedOperationException("Unexpected repository method: " + method.getName());
                });
    }
}
