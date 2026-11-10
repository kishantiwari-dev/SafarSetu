package in.safarsetu.backend.controller;

import in.safarsetu.backend.dto.*;
import in.safarsetu.backend.service.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api") @Validated
public class BusController {
    private final BusService buses;private final TicketService tickets;
    public BusController(BusService buses,TicketService tickets){this.buses=buses;this.tickets=tickets;}
    @GetMapping("/buses") public Page<BusDto> listBuses(@PageableDefault(size=20,sort="id") Pageable pageable){return buses.listBuses(pageable);}
    @GetMapping("/buses/search") public Page<BusDto> search(@RequestParam @NotBlank String fromStopId,@RequestParam @NotBlank String toStopId,@PageableDefault(size=20,sort="id") Pageable pageable){return buses.search(fromStopId,toStopId,pageable);}
    @GetMapping("/buses/{busId}") public BusDto bus(@PathVariable @NotBlank String busId){return buses.getBus(busId);}
    @GetMapping("/buses/{busId}/occupancy") public OccupancyDto occupancy(@PathVariable @NotBlank String busId,@RequestParam(required=false) @NotBlank String stopId,@RequestParam(required=false) @NotBlank String tripId){return buses.occupancy(busId,stopId,tripId);}
    @GetMapping("/buses/{busId}/location") public LocationDto location(@PathVariable @NotBlank String busId){return buses.location(busId);}
    @GetMapping("/buses/{busId}/eta") public EtaDto eta(@PathVariable @NotBlank String busId,@RequestParam @NotBlank String toStopId){return buses.eta(busId,toStopId);}
    @PostMapping("/etm/tickets") public ResponseEntity<TicketService.TicketReceipt> ticket(@Valid @RequestBody TicketRequest request){
        var receipt=tickets.ingest(request);return ResponseEntity.status(201).body(receipt);
    }
}
