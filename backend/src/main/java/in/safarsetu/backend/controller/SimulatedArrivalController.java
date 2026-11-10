package in.safarsetu.backend.controller;
import in.safarsetu.backend.dto.SimulatedArrivalRequest;
import in.safarsetu.backend.service.SimulatedArrivalService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/etm/simulated")
public class SimulatedArrivalController {
 private final SimulatedArrivalService arrivals;
 public SimulatedArrivalController(SimulatedArrivalService arrivals){this.arrivals=arrivals;}
 @PostMapping("/arrivals") public ResponseEntity<SimulatedArrivalService.ArrivalReceipt> arrive(@Valid @RequestBody SimulatedArrivalRequest request){return ResponseEntity.status(201).body(arrivals.arrive(request));}
}
