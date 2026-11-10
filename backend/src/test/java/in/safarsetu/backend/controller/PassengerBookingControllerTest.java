package in.safarsetu.backend.controller;

import in.safarsetu.backend.service.PassengerBookingService;
import in.safarsetu.backend.exception.ApiExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class PassengerBookingControllerTest {
    private final PassengerBookingService service = mock(PassengerBookingService.class);
    private final LocalValidatorFactoryBean validator = validator();
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new PassengerBookingController(service))
            .setValidator(validator).setControllerAdvice(new ApiExceptionHandler()).build();

    @Test void returnsCreatedSimulationReceiptFromBackend() throws Exception {
        when(service.create(any())).thenReturn(new PassengerBookingService.BookingReceipt(
                "ATM-123", "booking-1", "SIM-TRIP-BUS-1-DEMO-01", "BUS-1", "A", "Alpha", "B", "Beta", 2,
                "CONFIRMED_SIMULATION", "SIMULATED", "NOT_BOARDING_EVIDENCE", Instant.parse("2026-10-26T10:00:00Z")));

        mvc.perform(post("/api/atm/bookings").contentType(MediaType.APPLICATION_JSON).content("""
                {"idempotencyKey":"retry-key","tripId":"SIM-TRIP-BUS-1-DEMO-01","busId":"BUS-1","boardingStopId":"A","destinationStopId":"B","passengerCount":2}
                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.bookingReference").value("ATM-123"))
                .andExpect(jsonPath("$.bookingStatus").value("CONFIRMED_SIMULATION"))
                .andExpect(jsonPath("$.boardingStatus").value("NOT_BOARDING_EVIDENCE"));
        verify(service).create(argThat(request -> "retry-key".equals(request.idempotencyKey()) && request.passengerCount() == 2));
    }

    @Test void rejectsNonPositiveQuantityBeforeCallingService() throws Exception {
        mvc.perform(post("/api/atm/bookings").contentType(MediaType.APPLICATION_JSON).content("""
                {"idempotencyKey":"retry-key","tripId":"SIM-TRIP-BUS-1-DEMO-01","busId":"BUS-1","boardingStopId":"A","destinationStopId":"B","passengerCount":0}
                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.passengerCount").exists());
        verifyNoInteractions(service);
    }

    private static LocalValidatorFactoryBean validator() {
        var validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();
        return validator;
    }
}
