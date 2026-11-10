package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;
import java.time.Instant;

@Entity @Table(name="tickets",uniqueConstraints={@UniqueConstraint(columnNames="idempotency_key"),@UniqueConstraint(columnNames="booking_id")},indexes={@Index(columnList="bus_id,boarded_at"),@Index(name="idx_tickets_bus_trip_boarded_at",columnList="bus_id,trip_id,boarded_at")}) @Check(constraints="passenger_count > 0")
public class Ticket {
    @Id @Column(length=64) private String id;
    @Column(name="idempotency_key",nullable=false,length=100) private String idempotencyKey;
    @Column(name="trip_id",length=64) private String tripId;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="bus_id") private Bus bus;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="boarding_stop_id") private Stop boardingStop;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="destination_stop_id") private Stop destinationStop;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="booking_id") private PassengerBooking booking;
    @Column(nullable=false) private int passengerCount;
    @Column(name="boarded_at",nullable=false) private Instant boardedAt;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DataOrigin dataOrigin;
    protected Ticket() {}
    public Ticket(String id,String idempotencyKey,Bus bus,Stop boardingStop,Stop destinationStop,int passengerCount,Instant boardedAt,DataOrigin dataOrigin,String tripId){this(id,idempotencyKey,bus,boardingStop,destinationStop,passengerCount,boardedAt,dataOrigin,tripId,null);}
    public Ticket(String id,String idempotencyKey,Bus bus,Stop boardingStop,Stop destinationStop,int passengerCount,Instant boardedAt,DataOrigin dataOrigin,String tripId,PassengerBooking booking){this.id=id;this.idempotencyKey=idempotencyKey;this.tripId=tripId;this.bus=bus;this.boardingStop=boardingStop;this.destinationStop=destinationStop;this.passengerCount=passengerCount;this.boardedAt=boardedAt;this.dataOrigin=dataOrigin;this.booking=booking;}
    /** Backward-compatible constructor for explicitly unassigned legacy/test rows. */
    public Ticket(String id,String idempotencyKey,Bus bus,Stop boardingStop,Stop destinationStop,int passengerCount,Instant boardedAt,DataOrigin dataOrigin){this(id,idempotencyKey,bus,boardingStop,destinationStop,passengerCount,boardedAt,dataOrigin,null);}
    public String getId(){return id;} public String getIdempotencyKey(){return idempotencyKey;} public String getTripId(){return tripId;} public Bus getBus(){return bus;} public Stop getBoardingStop(){return boardingStop;} public Stop getDestinationStop(){return destinationStop;} public PassengerBooking getBooking(){return booking;} public int getPassengerCount(){return passengerCount;} public Instant getBoardedAt(){return boardedAt;} public DataOrigin getDataOrigin(){return dataOrigin;}
}
