package in.safarsetu.backend.controller;

import in.safarsetu.backend.dto.*;
import in.safarsetu.backend.exception.ApiException;
import in.safarsetu.backend.exception.ApiExceptionHandler;
import in.safarsetu.backend.service.BusService;
import in.safarsetu.backend.service.TicketService;
import jakarta.validation.ConstraintViolationException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class RestApiControllerTest {
    private final BusService busService = mock(BusService.class);
    private final TicketService ticketService = mock(TicketService.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(
                    new BusController(busService, ticketService), new RouteController(busService), new HealthController())
            .setControllerAdvice(new ApiExceptionHandler()).build();

    @Test
    void exposesApplicationHealthAndRouteDetailsAndOrderedStops() throws Exception {
        when(busService.getRoute("SIM-GN-001")).thenReturn(new RouteDto("SIM-GN-001", "Mock corridor", "SIMULATED", true,
                "BOTANICAL_GARDEN", "ALPHA_1"));
        when(busService.routeStops("SIM-GN-001")).thenReturn(List.of(
                new StopDto("BOTANICAL_GARDEN", "Botanical Garden", 28.56, 77.33, "APPROXIMATE", 0),
                new StopDto("ALPHA_1", "Alpha 1", 28.47, 77.50, "APPROXIMATE", 1)));

        mvc.perform(get("/api/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
        mvc.perform(get("/api/routes/SIM-GN-001")).andExpect(status().isOk())
                .andExpect(jsonPath("$.dataOrigin").value("SIMULATED"));
        mvc.perform(get("/api/routes/SIM-GN-001/stops")).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].stopOrder").value(0)).andExpect(jsonPath("$[1].stopOrder").value(1));
    }

    @Test
    void returnsStructuredNotFoundForUnknownRoute() throws Exception {
        when(busService.getRoute("unknown")).thenThrow(ApiException.notFound("Route not found: unknown"));
        mvc.perform(get("/api/routes/unknown")).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404)).andExpect(jsonPath("$.path").value("/api/routes/unknown"));
    }

    @Test
    void passesExplicitTripContextToOccupancyService() throws Exception {
        when(busService.occupancy("BUS-SIM-001", "PARI_CHOWK", "trip-1")).thenReturn(new OccupancyDto(
                "BUS-SIM-001", "trip-1", "SIM-GN-001", "Sim route", "PARI_CHOWK", "Pari Chowk", 4,
                Instant.parse("2026-10-24T08:00:00Z"), Instant.parse("2026-10-24T07:55:00Z"), "SIMULATED", "LOW", 3, 35, 50, 32, "AFTER_STOP_EVENTS", "CALCULATED",
                "Selected trip only", List.of(), "SIMULATED", 3, 4, 43));

        mvc.perform(get("/api/buses/BUS-SIM-001/occupancy")
                        .param("stopId", "PARI_CHOWK").param("tripId", "trip-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tripId").value("trip-1"))
                .andExpect(jsonPath("$.onboardPassengers").value(3))
                .andExpect(jsonPath("$.ticketDerivedOnboardPassengers").value(3))
                .andExpect(jsonPath("$.confirmedReservedPassengers").value(4))
                .andExpect(jsonPath("$.remainingPassengerCapacity").value(43))
                .andExpect(jsonPath("$.totalPassengerCapacity").value(50));
        verify(busService).occupancy("BUS-SIM-001", "PARI_CHOWK", "trip-1");
    }

    @Test
    void hidesConstraintInternalsAndReportsDatabaseUnavailableSafely() throws Exception {
        when(busService.getRoute("invalid")).thenThrow(new ConstraintViolationException("internal validator detail", java.util.Set.of()));
        mvc.perform(get("/api/routes/invalid"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.parameter").value("One or more request parameters are invalid"))
                .andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("internal validator detail"))));

        when(busService.getRoute("db-down")).thenThrow(new DataAccessResourceFailureException("password=secret jdbc:postgresql://private"));
        mvc.perform(get("/api/routes/db-down"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.message").value("The database is temporarily unavailable"))
                .andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("password=secret"))));
    }

    @Test
    void createsTicketWith201AndDoesNotAcceptClientSourceClassification() throws Exception {
        when(ticketService.ingest(any())).thenReturn(new TicketService.TicketReceipt(
                "ticket-1", "BUS-SIM-001", "trip-1", 2, Instant.parse("2026-10-24T08:00:00Z"), "SIMULATED", "ACCEPTED"));
        mvc.perform(post("/api/etm/tickets").contentType(MediaType.APPLICATION_JSON).content("""
                {"ticketId":"ticket-1","idempotencyKey":"event-1","busId":"BUS-SIM-001","boardingStopId":"PARI_CHOWK","destinationStopId":"ALPHA_1","passengerCount":2,"boardedAt":"2026-10-24T08:00:00Z","tripId":"trip-1"}
                """))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.ticketId").value("ticket-1"))
                .andExpect(jsonPath("$.tripId").value("trip-1"))
                .andExpect(jsonPath("$.dataOrigin").value("SIMULATED"))
                .andExpect(jsonPath("$.eventStatus").value("ACCEPTED"));
        verify(ticketService).ingest(any());
    }
}




