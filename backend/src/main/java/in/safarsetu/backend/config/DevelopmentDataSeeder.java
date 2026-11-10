package in.safarsetu.backend.config;

import in.safarsetu.backend.entity.*;
import in.safarsetu.backend.repository.*;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;

/** Stable development fixtures only. Existing rows are never cleared or overwritten. */
@Configuration @Profile("dev")
public class DevelopmentDataSeeder {
    // Recent synthetic tracks stay usable for the local stale-location demo. Once inserted,
    // stable IDs make this anchor persistent across restarts; records are never rewritten.
    private static final Instant BASE=Instant.now().truncatedTo(ChronoUnit.MINUTES).minusSeconds(45*60L);
    private record S(String id,String name,double lat,double lon){}
    private record R(String id,String name,List<String> stops){}
    private record B(String id,String route,int seats,int total){}
    private record T(String id,String bus,int from,int to,int count,int minute){String tripId(){return demoTripId(bus);}}
    private static String demoTripId(String busId){return "SIM-TRIP-"+busId+"-DEMO-01";}

    @Bean @ConditionalOnProperty(name="safarsetu.seed.enabled",havingValue="true",matchIfMissing=true)
    ApplicationRunner seed(StopRepository stopRepo,RouteRepository routeRepo,RouteStopRepository routeStopRepo,BusRepository busRepo,TicketRepository ticketRepo,BusLocationRepository locationRepo,OccupancySnapshotRepository snapshotRepo){
        return args->seedData(stopRepo,routeRepo,routeStopRepo,busRepo,ticketRepo,locationRepo,snapshotRepo);
    }
    @Transactional
    void seedData(StopRepository sr,RouteRepository rr,RouteStopRepository rsr,BusRepository br,TicketRepository tr,BusLocationRepository lr,OccupancySnapshotRepository or){
        List<S> stops=List.of(
            s("BOTANICAL_GARDEN","Botanical Garden",28.5647,77.3340),s("SECTOR_18","Noida Sector 18 / Atta Market",28.5708,77.3261),
            s("SECTOR_62","Noida Sector 62",28.6270,77.3725),s("SECTOR_51","Noida Sector 51",28.5834,77.3730),
            s("SECTOR_76","Noida Sector 76",28.5678,77.3761),s("SECTOR_137","Noida Sector 137",28.5065,77.4050),
            s("SECTOR_142","Noida Sector 142",28.4939,77.4107),s("SECTOR_148","Noida Sector 148",28.4774,77.4170),
            s("KP_II","Knowledge Park II",28.4578,77.5000),s("PARI_CHOWK","Pari Chowk",28.4652,77.5080),
            s("ALPHA_1","Alpha 1",28.4712,77.5070),s("DELTA_1","Delta 1",28.4772,77.5140),
            s("GNIDA","Greater Noida Authority",28.4740,77.5030),s("KASNA","Kasna",28.4070,77.5050),
            s("SHARDA","Sharda University",28.4720,77.4830),s("GBU","Gautam Buddha University",28.4190,77.5300),
            s("SURJPUR","Surajpur",28.5200,77.4850),s("DADRI_RAIL","Dadri Railway Station",28.5525,77.5545),
            s("GAUR_CITY","Gaur City",28.6070,77.4350),s("KISAN_CHOWK","Kisan Chowk",28.6130,77.4490),
            s("GREATER_NOIDA_WEST","Greater Noida West",28.5950,77.4450),s("DEPOT","Depot Station",28.4510,77.5350));
        Map<String,Stop> sm=new HashMap<>();
        for(S x:stops){
            Stop value=sr.findById(x.id()).orElseGet(()->sr.save(new Stop(x.id(),x.name(),x.lat(),x.lon(),VerificationStatus.APPROXIMATE)));
            if(value==null || !x.id().equals(value.getId()))throw new IllegalStateException("Development seed stop lookup for '"+x.id()+"' returned no matching persisted stop.");
            sm.put(value.getId(),value);
        }
        List<R> routes=List.of(
            r("SIM-GN-001","SIMULATED Noida Sector 18–Knowledge Park–Pari Chowk", "BOTANICAL_GARDEN","SECTOR_18","SECTOR_62","KP_II","PARI_CHOWK","ALPHA_1"),
            r("SIM-GN-002","SIMULATED Sector 62–Greater Noida Authority", "SECTOR_62","SECTOR_51","SECTOR_76","KP_II","DELTA_1","GNIDA"),
            r("SIM-GN-003","SIMULATED Greater Noida West–Noida Sector 62", "GAUR_CITY","KISAN_CHOWK","GREATER_NOIDA_WEST","SECTOR_51","SECTOR_62"),
            r("SIM-GN-004","SIMULATED Kasna–University–Pari Chowk", "KASNA","SHARDA","GBU","SURJPUR","DELTA_1","PARI_CHOWK"),
            r("SIM-GN-005","SIMULATED Aqua corridor feeder–Knowledge Park", "SECTOR_51","SECTOR_76","SECTOR_137","SECTOR_142","SECTOR_148","KP_II"),
            r("SIM-GN-006","SIMULATED Dadri–Greater Noida Depot", "DADRI_RAIL","GBU","KASNA","KP_II","PARI_CHOWK","DEPOT"),
            r("SIM-GN-007","SIMULATED Alpha–Delta–Depot connector", "KP_II","PARI_CHOWK","ALPHA_1","DELTA_1","GNIDA","DEPOT"),
            r("SIM-GN-008","SIMULATED Noida Sector 18–Greater Noida West", "SECTOR_18","BOTANICAL_GARDEN","SECTOR_51","GREATER_NOIDA_WEST","GAUR_CITY"),
            r("SIM-GN-009","SIMULATED Alpha–Botanical Garden reverse corridor", "ALPHA_1","PARI_CHOWK","KP_II","SECTOR_62","SECTOR_18","BOTANICAL_GARDEN"));
        Map<String,Route> rm=new HashMap<>();
        for(R x:routes){Route route=rr.findById(x.id()).orElseGet(()->rr.save(new Route(x.id(),x.name(),DataOrigin.SIMULATED,true)));rm.put(x.id(),route);for(int i=0;i<x.stops().size();i++){Stop stop=sm.get(x.stops().get(i));RouteStopId id=new RouteStopId(x.id(),stop.getId());if(!rsr.existsById(id))rsr.save(new RouteStop(route,stop,i));}}
        List<B> buses=List.of(new B("BUS-SIM-001","SIM-GN-001",35,50),new B("BUS-SIM-002","SIM-GN-002",40,55),new B("BUS-SIM-003","SIM-GN-003",40,55),new B("BUS-SIM-004","SIM-GN-004",30,45),new B("BUS-SIM-005","SIM-GN-005",35,50),new B("BUS-SIM-006","SIM-GN-006",32,48),new B("BUS-SIM-007","SIM-GN-007",38,52),new B("BUS-SIM-008","SIM-GN-008",35,50),new B("BUS-SIM-009","SIM-GN-001",50,50),new B("BUS-SIM-010","SIM-GN-001",50,50),new B("BUS-SIM-011","SIM-GN-009",50,50),new B("BUS-SIM-012","SIM-GN-009",50,50),new B("BUS-SIM-013","SIM-GN-009",50,50));
        Map<String,Bus> bm=new HashMap<>();for(B x:buses)bm.put(x.id(),br.findById(x.id()).orElseGet(()->br.save(new Bus(x.id(),x.id(),x.seats(),x.total(),rm.get(x.route()),DataOrigin.SIMULATED,true))));
        List<T> events=List.of(
            new T("T-SIM-001","BUS-SIM-001",0,4,3,1),new T("T-SIM-002","BUS-SIM-001",2,5,2,8),new T("T-SIM-003","BUS-SIM-001",3,4,4,12),
            new T("T-SIM-004","BUS-SIM-002",0,3,8,1),new T("T-SIM-005","BUS-SIM-002",1,4,6,6),new T("T-SIM-006","BUS-SIM-002",2,5,4,11),
            new T("T-SIM-007","BUS-SIM-003",0,4,20,1),new T("T-SIM-008","BUS-SIM-003",1,4,18,6),new T("T-SIM-009","BUS-SIM-003",2,4,13,11),
            new T("T-SIM-010","BUS-SIM-004",0,3,2,2),new T("T-SIM-011","BUS-SIM-004",2,5,2,13),
            new T("T-SIM-012","BUS-SIM-006",0,4,3,2),new T("T-SIM-013","BUS-SIM-006",2,5,5,14),
            new T("T-SIM-014","BUS-SIM-007",0,3,12,2),new T("T-SIM-015","BUS-SIM-007",1,4,10,7),
            new T("T-SIM-016","BUS-SIM-008",0,3,16,2),new T("T-SIM-017","BUS-SIM-008",2,4,14,14),
            new T("T-SIM-018","BUS-SIM-001",4,5,2,16),
            new T("T-DEMO-009","BUS-SIM-009",0,5,32,1),new T("T-DEMO-010","BUS-SIM-010",0,5,48,1),
            new T("T-DEMO-011","BUS-SIM-011",0,5,18,1),new T("T-DEMO-012","BUS-SIM-012",0,5,32,1),new T("T-DEMO-013","BUS-SIM-013",0,5,48,1));
        for(T e:events){if(tr.existsById(e.id()))continue;B spec=buses.stream().filter(v->v.id().equals(e.bus())).findFirst().orElseThrow();Route route=rm.get(spec.route());List<RouteStop> seq=rsr.findByRoute_IdOrderByStopOrder(route.getId());tr.save(new Ticket(e.id(),"KEY-"+e.id(),bm.get(e.bus()),sm.get(seq.get(e.from()).getStop().getId()),sm.get(seq.get(e.to()).getStop().getId()),e.count(),BASE.plusSeconds(e.minute()*60L),DataOrigin.SIMULATED,e.tripId()));}
        seedLocations(lr,bm,sm);
        Map<String,Integer> snapshotCounts=Map.ofEntries(Map.entry("BUS-SIM-001",5),Map.entry("BUS-SIM-002",18),Map.entry("BUS-SIM-003",51),Map.entry("BUS-SIM-004",4),Map.entry("BUS-SIM-006",8),Map.entry("BUS-SIM-007",22),Map.entry("BUS-SIM-008",16),Map.entry("BUS-SIM-009",32),Map.entry("BUS-SIM-010",48),Map.entry("BUS-SIM-011",18),Map.entry("BUS-SIM-012",32),Map.entry("BUS-SIM-013",48));
        for(B b:buses){String id="SNAP-"+b.id();if(or.existsById(id))continue;Integer count=snapshotCounts.get(b.id());DataQuality q=count==null?DataQuality.NO_TICKET_DATA:DataQuality.COMPLETE;String assumption=count==null?"No ticket events had been recorded as of this snapshot; zero is not an observed count.":"Calculated from simulated ticket events at the simulated location stop; seated/standing split is unknown.";Instant snapAt=b.id().equals("BUS-SIM-008")?BASE.minusSeconds(86400):BASE.plusSeconds(2700);or.save(new OccupancySnapshot(id,bm.get(b.id()),snapAt,count==null?0:count,null,q,assumption));}
    }
    private static S s(String id,String name,double lat,double lon){return new S(id,name,lat,lon);}
    private static R r(String id,String name,String... stops){return new R(id,name,List.of(stops));}
    void seedLocations(BusLocationRepository lr,Map<String,Bus> buses,Map<String,Stop> stops){
        String[][] tracks={{"BUS-SIM-001","BOTANICAL_GARDEN","SECTOR_18","SECTOR_62"},{"BUS-SIM-002","SECTOR_62","SECTOR_51","SECTOR_76"},{"BUS-SIM-003","GAUR_CITY","KISAN_CHOWK","GREATER_NOIDA_WEST"},{"BUS-SIM-004","KASNA","SHARDA","GBU"},{"BUS-SIM-006","DADRI_RAIL","GBU","KASNA"},{"BUS-SIM-007","KP_II","PARI_CHOWK","ALPHA_1"}};
        for(String[] track:tracks){
            Bus bus=requireBus(buses,track[0]);
            for(int i=1;i<track.length;i++){
                String stopId=track[i];Stop stop=requireStop(stops,stopId);
                String id="LOC-"+track[0]+"-"+(i-1);if(lr.existsById(id))continue;
                lr.save(new BusLocation(id,bus,stop.getLatitude()+.0007,stop.getLongitude()+.0004,BASE.plusSeconds(i*900L),DataOrigin.SIMULATED));
            }
        }
        Bus bus=requireBus(buses,"BUS-SIM-008");Stop stop=requireStop(stops,"SECTOR_18");
        if(!lr.existsById("LOC-BUS-SIM-008-OLD"))lr.save(new BusLocation("LOC-BUS-SIM-008-OLD",bus,stop.getLatitude(),stop.getLongitude(),BASE.minusSeconds(86400),DataOrigin.SIMULATED));
    }
    private static Stop requireStop(Map<String,Stop> stops,String stopId){
        Stop stop=stops.get(stopId);
        if(stop==null || !stopId.equals(stop.getId()))throw new IllegalStateException("Development seed location references missing stop '"+stopId+"'. Ensure the stop is seeded and persisted before location records.");
        return stop;
    }
    private static Bus requireBus(Map<String,Bus> buses,String busId){
        Bus bus=buses.get(busId);
        if(bus==null || !busId.equals(bus.getId()))throw new IllegalStateException("Development seed location references missing bus '"+busId+"'. Ensure the bus is seeded and persisted before location records.");
        return bus;
    }
}
