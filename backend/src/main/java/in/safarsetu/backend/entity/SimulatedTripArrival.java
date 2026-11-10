package in.safarsetu.backend.entity;
import jakarta.persistence.*;
import java.time.Instant;
@Entity @Table(name="simulated_trip_arrivals", uniqueConstraints=@UniqueConstraint(name="uq_sim_arrival_bus_trip_order",columnNames={"bus_id","trip_id","stop_order"}))
public class SimulatedTripArrival {
 @Id @Column(name="event_id",length=64) private String eventId;
 @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="bus_id",nullable=false) private Bus bus;
 @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="stop_id",nullable=false) private Stop stop;
 @Column(name="trip_id",nullable=false,length=64) private String tripId;
 @Column(name="stop_order",nullable=false) private int stopOrder;
 @Column(name="arrived_at",nullable=false) private Instant arrivedAt;
 @Column(name="simulated_alighting_passengers",nullable=false) private int simulatedAlightingPassengers;
 @Enumerated(EnumType.STRING) @Column(name="data_origin",nullable=false,length=16) private DataOrigin dataOrigin=DataOrigin.SIMULATED;
 protected SimulatedTripArrival() {}
 public SimulatedTripArrival(String eventId,Bus bus,Stop stop,String tripId,int stopOrder,Instant arrivedAt,int alighting){this.eventId=eventId;this.bus=bus;this.stop=stop;this.tripId=tripId;this.stopOrder=stopOrder;this.arrivedAt=arrivedAt;this.simulatedAlightingPassengers=alighting;}
 public String getEventId(){return eventId;} public Bus getBus(){return bus;} public Stop getStop(){return stop;} public String getTripId(){return tripId;} public int getStopOrder(){return stopOrder;} public Instant getArrivedAt(){return arrivedAt;} public int getSimulatedAlightingPassengers(){return simulatedAlightingPassengers;} public DataOrigin getDataOrigin(){return dataOrigin;}
}

