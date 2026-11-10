package in.safarsetu.backend.repository;
import in.safarsetu.backend.entity.BusLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface BusLocationRepository extends JpaRepository<BusLocation,String> {
    Optional<BusLocation> findFirstByBus_IdOrderByRecordedAtDesc(String busId);
}
