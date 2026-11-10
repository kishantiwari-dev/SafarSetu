package in.safarsetu.backend.dto;
import jakarta.validation.constraints.*;
import java.time.Instant;
public record SimulatedArrivalRequest(@NotBlank @Size(max=64) String eventId,@NotBlank @Size(max=64) String tripId,@NotBlank String busId,@NotBlank String stopId,@NotNull Instant arrivedAt) {}
