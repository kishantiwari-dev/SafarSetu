package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;

import java.time.Instant;

/** A quantity-based reservation; it is never evidence that passengers boarded. */
@Entity
@Table(name = "passenger_bookings", uniqueConstraints = @UniqueConstraint(columnNames = "idempotency_key"),
        indexes = @Index(name = "idx_bookings_bus_trip_created", columnList = "bus_id,trip_id,created_at"))
@Check(constraints = "passenger_count > 0")
public class PassengerBooking {
    @Id @Column(length = 64) private String id;
    @Column(name = "booking_reference", nullable = false, unique = true, length = 64) private String bookingReference;
    @Column(name = "idempotency_key", nullable = false, length = 100) private String idempotencyKey;
    @Column(name = "trip_id", nullable = false, length = 64) private String tripId;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "bus_id", nullable = false) private Bus bus;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "boarding_stop_id", nullable = false) private Stop boardingStop;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "destination_stop_id", nullable = false) private Stop destinationStop;
    @Column(name = "passenger_count", nullable = false) private int passengerCount;
    @Column(nullable = false, length = 32) private String status;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected PassengerBooking() {}

    public PassengerBooking(String id, String bookingReference, String idempotencyKey, String tripId,
                            Bus bus, Stop boardingStop, Stop destinationStop, int passengerCount,
                            String status, Instant createdAt) {
        this.id = id;
        this.bookingReference = bookingReference;
        this.idempotencyKey = idempotencyKey;
        this.tripId = tripId;
        this.bus = bus;
        this.boardingStop = boardingStop;
        this.destinationStop = destinationStop;
        this.passengerCount = passengerCount;
        this.status = status;
        this.createdAt = createdAt;
    }

    public String getId() { return id; }
    public String getBookingReference() { return bookingReference; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public String getTripId() { return tripId; }
    public Bus getBus() { return bus; }
    public Stop getBoardingStop() { return boardingStop; }
    public Stop getDestinationStop() { return destinationStop; }
    public int getPassengerCount() { return passengerCount; }
    public String getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public void markSimulatedBoardingRecorded() {
        if (!"CONFIRMED_SIMULATION".equals(status)) throw new IllegalStateException("Only a confirmed simulation booking can be linked to a boarding event");
        status = "BOARDING_RECORDED_SIMULATION";
    }
}
