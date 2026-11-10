package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;

@Entity @Table(name="route_stops",uniqueConstraints=@UniqueConstraint(columnNames={"route_id","stop_order"}),indexes=@Index(columnList="stop_id")) @Check(constraints="stop_order >= 0")
public class RouteStop {
    @EmbeddedId private RouteStopId id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @MapsId("routeId") @JoinColumn(name="route_id") private Route route;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @MapsId("stopId") @JoinColumn(name="stop_id") private Stop stop;
    @Column(name="stop_order",nullable=false) private int stopOrder;
    protected RouteStop() {}
    public RouteStop(Route route,Stop stop,int stopOrder){this.id=new RouteStopId(route.getId(),stop.getId());this.route=route;this.stop=stop;this.stopOrder=stopOrder;}
    public Route getRoute(){return route;} public Stop getStop(){return stop;} public int getStopOrder(){return stopOrder;}
}
