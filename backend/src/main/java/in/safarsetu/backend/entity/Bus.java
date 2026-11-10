package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.Positive;
import org.hibernate.annotations.Check;

@Entity @Table(name="buses") @Check(constraints="seating_capacity > 0 AND (total_passenger_capacity IS NULL OR total_passenger_capacity >= seating_capacity)")
public class Bus {
    @Id @Column(length=32) private String id;
    @Column(nullable=false, unique=true, length=32) private String fleetCode;
    @Positive @Column(nullable=false) private int seatingCapacity;
    private Integer totalPassengerCapacity;
    @ManyToOne(fetch=FetchType.LAZY, optional=false) @JoinColumn(name="route_id") private Route route;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DataOrigin dataOrigin;
    @Column(nullable=false) private boolean active;
    protected Bus() {}
    public Bus(String id,String fleetCode,int seatingCapacity,Integer totalPassengerCapacity,Route route,DataOrigin dataOrigin,boolean active){this.id=id;this.fleetCode=fleetCode;this.seatingCapacity=seatingCapacity;this.totalPassengerCapacity=totalPassengerCapacity;this.route=route;this.dataOrigin=dataOrigin;this.active=active;}
    public String getId(){return id;} public String getFleetCode(){return fleetCode;} public int getSeatingCapacity(){return seatingCapacity;} public Integer getTotalPassengerCapacity(){return totalPassengerCapacity;} public Route getRoute(){return route;} public DataOrigin getDataOrigin(){return dataOrigin;} public boolean isActive(){return active;}
}
