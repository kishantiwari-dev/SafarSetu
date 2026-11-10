package in.safarsetu.backend.controller;

import in.safarsetu.backend.dto.TicketRequest;
import in.safarsetu.backend.service.TicketService;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.mockito.Mockito.*;

class TicketValidationTest {
    @Test void invalidTicketRequestReturnsConsistentJsonFieldErrors() throws Exception {
        var ticketService=mock(TicketService.class);var validator=new LocalValidatorFactoryBean();validator.afterPropertiesSet();
        MockMvc mvc=MockMvcBuilders.standaloneSetup(new BusController(null,ticketService)).setValidator(validator).setControllerAdvice(new in.safarsetu.backend.exception.ApiExceptionHandler()).build();
        mvc.perform(post("/api/etm/tickets").contentType("application/json").content("""
            {"ticketId":"t","idempotencyKey":"key","busId":"bus","boardingStopId":"a","destinationStopId":"b","passengerCount":0,"boardedAt":"2026-10-11T06:00:00Z"}
            """))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.error").value("Bad Request"))
            .andExpect(jsonPath("$.fieldErrors.passengerCount").exists())
            .andExpect(jsonPath("$.fieldErrors.tripId").exists());
        verifyNoInteractions(ticketService);
    }
}
