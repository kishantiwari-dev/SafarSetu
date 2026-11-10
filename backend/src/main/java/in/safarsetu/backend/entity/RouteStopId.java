package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import java.io.Serializable;
import java.util.Objects;

@Embeddable
public class RouteStopId implements Serializable {
    @Column(name="route_id",length=32) private String routeId;
    @Column(name="stop_id",length=40) private String stopId;
    protected RouteStopId() {}
    public RouteStopId(String routeId,String stopId){this.routeId=routeId;this.stopId=stopId;}
    @Override public boolean equals(Object o){if(this==o)return true;if(!(o instanceof RouteStopId that))return false;return Objects.equals(routeId,that.routeId)&&Objects.equals(stopId,that.stopId);}
    @Override public int hashCode(){return Objects.hash(routeId,stopId);}
}
