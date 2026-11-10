package in.safarsetu.backend.dto;
import jakarta.validation.constraints.*;
import java.time.Instant;
public record TicketRequest(@NotBlank @Size(max=64) String ticketId,@NotBlank @Size(max=100) String idempotencyKey,@NotBlank String busId,@NotBlank String boardingStopId,@NotBlank String destinationStopId,@Positive int passengerCount,@NotNull Instant boardedAt,@NotBlank @Size(max=64) String tripId,@Size(max=64) String bookingReference) {
    public TicketRequest(String ticketId,String idempotencyKey,String busId,String boardingStopId,String destinationStopId,int passengerCount,Instant boardedAt,String tripId){this(ticketId,idempotencyKey,busId,boardingStopId,destinationStopId,passengerCount,boardedAt,tripId,null);}
}
