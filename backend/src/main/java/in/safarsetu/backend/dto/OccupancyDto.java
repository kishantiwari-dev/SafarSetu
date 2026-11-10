package in.safarsetu.backend.dto;

import java.time.Instant;
import java.util.List;

public record OccupancyDto(
        String busId,
        String tripId,
        String routeId,
        String routeName,
        String stopId,
        String stopName,
        Integer stopOrder,
        Instant calculatedAt,
        Instant dataUpdatedAt,
        String freshnessStatus,
        String crowdingCategory,
        Integer onboardPassengers,
        Integer seatingCapacity,
        Integer totalPassengerCapacity,
        Integer provisionalAvailableSeats,
        String calculationConvention,
        String occupancyStatus,
        String seatEstimateAssumption,
        List<String> dataQualityWarnings,
        String dataOrigin,
        Integer ticketDerivedOnboardPassengers,
        Integer confirmedReservedPassengers,
        Integer remainingPassengerCapacity) {
    public OccupancyDto {
        dataQualityWarnings = dataQualityWarnings == null ? List.of() : List.copyOf(dataQualityWarnings);
    }

    /** Backward-compatible constructor for callers using the original response fields. */
    public OccupancyDto(String busId, String tripId, String routeId, String routeName,
                        String stopId, String stopName, Integer stopOrder, Instant calculatedAt,
                        Instant dataUpdatedAt, String freshnessStatus, String crowdingCategory,
                        Integer onboardPassengers, Integer seatingCapacity, Integer totalPassengerCapacity,
                        Integer provisionalAvailableSeats, String calculationConvention, String occupancyStatus,
                        String seatEstimateAssumption, List<String> dataQualityWarnings, String dataOrigin) {
        this(busId, tripId, routeId, routeName, stopId, stopName, stopOrder, calculatedAt, dataUpdatedAt,
                freshnessStatus, crowdingCategory, onboardPassengers, seatingCapacity, totalPassengerCapacity,
                provisionalAvailableSeats, calculationConvention, occupancyStatus, seatEstimateAssumption,
                dataQualityWarnings, dataOrigin, onboardPassengers, null, null);
    }
}
