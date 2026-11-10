package in.safarsetu.backend.service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Calculates route-position occupancy after all events at the queried stop. */
public class OccupancyCalculator {
    public record Journey(String ticketId, int passengers, int boardingOrder, int destinationOrder) {}

    public record Result(int onboardPassengers, boolean hasEvents) {}

    /**
     * A ticket contributes at q exactly when it has boarded by q and exits after q:
     * boardOrder <= q && destinationOrder > q.
     * Ticket timestamps and repository ordering do not affect this route-position estimate.
     */
    public Result atStop(List<Journey> journeys, int queryOrder, int routeStopCount, Integer passengerCapacity) {
        if (journeys == null) throw new IllegalArgumentException("journeys are required");
        if (routeStopCount < 2) throw new IllegalArgumentException("route must have at least two ordered stops");
        if (queryOrder < 0 || queryOrder >= routeStopCount) {
            throw new IllegalArgumentException("query stop is outside the route");
        }
        if (passengerCapacity != null && passengerCapacity <= 0) {
            throw new IllegalArgumentException("passenger capacity must be positive when provided");
        }

        Set<String> ticketIds = new HashSet<>();
        long onboard = 0;
        for (Journey journey : journeys) {
            if (journey == null) throw new IllegalArgumentException("ticket journey is required");
            if (journey.ticketId() == null || journey.ticketId().isBlank()) {
                throw new IllegalArgumentException("ticket identifier is required");
            }
            if (!ticketIds.add(journey.ticketId())) {
                throw new IllegalStateException("Duplicate ticket identifier in occupancy data: " + journey.ticketId());
            }
            if (journey.passengers() <= 0) throw new IllegalArgumentException("passengers must be positive");
            if (journey.boardingOrder() < 0 || journey.destinationOrder() >= routeStopCount
                    || journey.destinationOrder() <= journey.boardingOrder()) {
                throw new IllegalArgumentException("boarding and destination must be valid ordered stops on the route");
            }
            if (journey.boardingOrder() <= queryOrder && journey.destinationOrder() > queryOrder) {
                onboard += journey.passengers();
                if (passengerCapacity != null && onboard > passengerCapacity) {
                    throw new IllegalStateException("Calculated occupancy exceeds known passenger capacity");
                }
                if (onboard > Integer.MAX_VALUE) {
                    throw new IllegalStateException("Calculated occupancy exceeds supported numeric range");
                }
            }
        }
        return new Result((int) onboard, !journeys.isEmpty());
    }
}
