package in.safarsetu.backend.repository;
import in.safarsetu.backend.entity.RouteStop;
import in.safarsetu.backend.entity.RouteStopId;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
public interface RouteStopRepository extends JpaRepository<RouteStop,RouteStopId> {
    @EntityGraph(attributePaths={"route","stop"})
    List<RouteStop> findByRoute_IdOrderByStopOrder(String routeId);
    @EntityGraph(attributePaths={"route","stop"})
    @Query("select rs from RouteStop rs where rs.route.id in :routeIds order by rs.route.id asc, rs.stopOrder asc")
    List<RouteStop> findAllForRoutes(@Param("routeIds") java.util.Collection<String> routeIds);
    @Query("select distinct a.route from RouteStop a, RouteStop b where a.route.id=b.route.id and a.stop.id=:fromId and b.stop.id=:toId and a.stopOrder < b.stopOrder and a.route.active=true")
    List<in.safarsetu.backend.entity.Route> findRoutesServingJourney(@Param("fromId") String fromId,@Param("toId") String toId);
}
