package in.safarsetu.backend.repository;
import in.safarsetu.backend.entity.SimulatedTripArrival;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface SimulatedTripArrivalRepository extends JpaRepository<SimulatedTripArrival,String> {
 Optional<SimulatedTripArrival> findTopByBus_IdAndTripIdOrderByStopOrderDesc(String busId,String tripId);
 boolean existsByBus_IdAndTripIdAndStopOrder(String busId,String tripId,int stopOrder);
}
