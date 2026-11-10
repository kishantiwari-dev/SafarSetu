package in.safarsetu.backend.repository;

import in.safarsetu.backend.entity.PassengerBooking;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PassengerBookingRepository extends JpaRepository<PassengerBooking, String> {
    boolean existsByIdempotencyKey(String idempotencyKey);

    @EntityGraph(attributePaths = {"bus", "boardingStop", "destinationStop"})
    List<PassengerBooking> findByBus_IdAndTripIdAndStatus(String busId, String tripId, String status);

    @EntityGraph(attributePaths = {"bus", "boardingStop", "destinationStop"})
    List<PassengerBooking> findByBus_Id(String busId);

    @EntityGraph(attributePaths = {"bus", "boardingStop", "destinationStop"})
    List<PassengerBooking> findByBus_IdAndTripId(String busId, String tripId);

    Optional<PassengerBooking> findByIdempotencyKey(String idempotencyKey);

    @EntityGraph(attributePaths = {"bus", "boardingStop", "destinationStop"})
    Optional<PassengerBooking> findByBookingReference(String bookingReference);
}
