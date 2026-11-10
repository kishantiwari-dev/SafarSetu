package in.safarsetu.backend.controller;

import in.safarsetu.backend.dto.PassengerBookingRequest;
import in.safarsetu.backend.service.PassengerBookingService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/atm/bookings")
public class PassengerBookingController {
    private final PassengerBookingService bookings;

    public PassengerBookingController(PassengerBookingService bookings) { this.bookings = bookings; }

    @PostMapping
    public ResponseEntity<PassengerBookingService.BookingReceipt> create(@Valid @RequestBody PassengerBookingRequest request) {
        return ResponseEntity.status(201).body(bookings.create(request));
    }
}
