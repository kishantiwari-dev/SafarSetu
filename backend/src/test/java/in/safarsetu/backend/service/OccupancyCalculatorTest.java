package in.safarsetu.backend.service;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class OccupancyCalculatorTest {
    private final OccupancyCalculator calculator = new OccupancyCalculator();

    private List<OccupancyCalculator.Journey> pariChowkAlphaDelta() {
        return List.of(
                new OccupancyCalculator.Journey("early-exit", 8, 0, 2),
                new OccupancyCalculator.Journey("long-trip", 4, 0, 3),
                new OccupancyCalculator.Journey("intermediate", 5, 1, 3));
    }

    @Test
    void calculatesAfterStopEventsUsingInclusiveBoardingAndExclusiveDestination() {
        var journeys = pariChowkAlphaDelta();

        assertEquals(12, calculator.atStop(journeys, 0, 4, 50).onboardPassengers()); // Pari Chowk
        assertEquals(17, calculator.atStop(journeys, 1, 4, 50).onboardPassengers()); // Alpha 1
        assertEquals(9, calculator.atStop(journeys, 2, 4, 50).onboardPassengers()); // Delta 1
        assertEquals(0, calculator.atStop(journeys, 3, 4, 50).onboardPassengers()); // Last stop
    }

    @Test
    void excludesPassengersBeforeBoardingAndAtTheirDestination() {
        var journey = List.of(new OccupancyCalculator.Journey("one-party", 3, 1, 2));
        assertEquals(0, calculator.atStop(journey, 0, 3, 20).onboardPassengers());
        assertEquals(3, calculator.atStop(journey, 1, 3, 20).onboardPassengers());
        assertEquals(0, calculator.atStop(journey, 2, 3, 20).onboardPassengers());
    }

    @Test
    void supportsOverlappingTripsAndMultiplePassengersOnOneTicket() {
        var journeys = List.of(
                new OccupancyCalculator.Journey("party", 7, 0, 3),
                new OccupancyCalculator.Journey("overlap", 2, 1, 3));
        assertEquals(9, calculator.atStop(journeys, 2, 4, 20).onboardPassengers());
    }

    @Test
    void emptyTicketSetIsUnknownDataRatherThanAnObservedZero() {
        var result = calculator.atStop(List.of(), 1, 3, 40);
        assertEquals(0, result.onboardPassengers());
        assertFalse(result.hasEvents());
    }

    @Test
    void resultDoesNotDependOnRepositoryTicketOrderOrLateInsertionOrder() {
        var early = new OccupancyCalculator.Journey("early", 8, 0, 2);
        var middle = new OccupancyCalculator.Journey("middle", 4, 0, 3);
        var late = new OccupancyCalculator.Journey("late", 5, 1, 3);
        var firstResult = calculator.atStop(List.of(early, middle), 1, 4, 50);
        var finalForward = calculator.atStop(List.of(early, middle, late), 1, 4, 50);
        var finalReverse = calculator.atStop(List.of(late, middle, early), 1, 4, 50);

        assertEquals(12, firstResult.onboardPassengers());
        assertEquals(17, finalForward.onboardPassengers());
        assertEquals(finalForward, finalReverse);
    }

    @Test
    void detectsCapacityOverflowWithoutClamping() {
        assertThrows(IllegalStateException.class, () -> calculator.atStop(
                List.of(new OccupancyCalculator.Journey("too-many", 6, 0, 2)), 0, 3, 5));
    }

    @Test
    void rejectsInvalidTicketsDuplicateIdentifiersAndBadRouteBounds() {
        assertThrows(IllegalArgumentException.class, () -> calculator.atStop(
                List.of(new OccupancyCalculator.Journey("bad-order", 2, 2, 1)), 1, 3, 20));
        assertThrows(IllegalArgumentException.class, () -> calculator.atStop(
                List.of(new OccupancyCalculator.Journey("zero", 0, 0, 1)), 0, 3, 20));
        assertThrows(IllegalStateException.class, () -> calculator.atStop(List.of(
                new OccupancyCalculator.Journey("duplicate", 1, 0, 2),
                new OccupancyCalculator.Journey("duplicate", 1, 0, 2)), 1, 3, 20));
        assertThrows(IllegalArgumentException.class, () -> calculator.atStop(List.of(), 3, 3, 20));
        assertThrows(IllegalArgumentException.class, () -> calculator.atStop(
                List.of(new OccupancyCalculator.Journey("outside-route", 1, 0, 3)), 1, 3, 20));
    }
}
