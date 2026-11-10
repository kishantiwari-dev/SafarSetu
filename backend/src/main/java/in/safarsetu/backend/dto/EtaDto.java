package in.safarsetu.backend.dto;

import java.time.Instant;

/** Route-based arrival estimate. It is not a live traffic prediction. */
public record EtaDto(
        String busId,
        String destinationStopId,
        Integer etaMinutes,
        Double estimatedRouteDistanceKm,
        String status,
        String dataOrigin,
        String estimateType,
        String assumption,
        Instant locationRecordedAt,
        Instant calculatedAt) {}
