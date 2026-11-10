package in.safarsetu.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record PassengerBookingRequest(
        @NotBlank @Size(max = 100) String idempotencyKey,
        @NotBlank @Size(max = 64) String tripId,
        @NotBlank String busId,
        @NotBlank String boardingStopId,
        @NotBlank String destinationStopId,
        @Positive int passengerCount) {}
