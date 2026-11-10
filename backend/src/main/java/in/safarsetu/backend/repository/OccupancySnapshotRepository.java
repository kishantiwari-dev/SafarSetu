package in.safarsetu.backend.repository;
import in.safarsetu.backend.entity.OccupancySnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface OccupancySnapshotRepository extends JpaRepository<OccupancySnapshot,String> {
    Optional<OccupancySnapshot> findFirstByBus_IdOrderBySnapshotAtDesc(String busId);
}
