package in.safarsetu.backend.repository;
import in.safarsetu.backend.entity.Ticket;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface TicketRepository extends JpaRepository<Ticket,String> {
    boolean existsByIdempotencyKey(String key);
    @EntityGraph(attributePaths={"bus","boardingStop","destinationStop","booking"})
    List<Ticket> findByBus_IdOrderByBoardedAtAsc(String busId);
    @EntityGraph(attributePaths={"bus","boardingStop","destinationStop","booking"})
    List<Ticket> findByBus_IdAndTripIdOrderByBoardedAtAsc(String busId,String tripId);
    Optional<Ticket> findByIdempotencyKey(String key);
}
