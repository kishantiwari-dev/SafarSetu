package in.safarsetu.backend.service;

import in.safarsetu.backend.entity.RouteStop;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Shared validation for persisted route-specific stop order. */
final class RouteStopSequence {
    private RouteStopSequence() {}

    static List<RouteStop> requireValid(String routeId, List<RouteStop> sequence) {
        if (routeId == null || routeId.isBlank() || sequence == null || sequence.size() < 2) {
            throw new IllegalStateException("Route must have at least two ordered stops");
        }
        Set<String> stopIds = new HashSet<>();
        for (int i = 0; i < sequence.size(); i++) {
            RouteStop routeStop = sequence.get(i);
            if (routeStop == null || routeStop.getRoute() == null || routeStop.getStop() == null
                    || !routeId.equals(routeStop.getRoute().getId())
                    || routeStop.getStop().getId() == null
                    || routeStop.getStopOrder() != i
                    || !stopIds.add(routeStop.getStop().getId())) {
                throw new IllegalStateException("Route-stop sequence is incomplete or inconsistent for route " + routeId);
            }
        }
        return sequence;
    }

    static int indexOf(List<RouteStop> sequence, String stopId) {
        for (int i = 0; i < sequence.size(); i++) {
            if (sequence.get(i).getStop().getId().equals(stopId)) return i;
        }
        return -1;
    }
}
