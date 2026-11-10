package in.safarsetu.backend.controller;

import in.safarsetu.backend.dto.*;
import in.safarsetu.backend.service.BusService;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import jakarta.validation.constraints.NotBlank;
import org.springframework.validation.annotation.Validated;

@RestController @RequestMapping("/api") @Validated
public class RouteController {
    private final BusService service;
    public RouteController(BusService service){this.service=service;}
    @GetMapping("/routes") public Page<RouteDto> routes(@PageableDefault(size=20,sort="id") Pageable pageable){return service.listRoutes(pageable);}
    @GetMapping("/routes/{routeId}") public RouteDto route(@PathVariable @NotBlank String routeId){return service.getRoute(routeId);}
    @GetMapping("/routes/{routeId}/stops") public List<StopDto> routeStops(@PathVariable @NotBlank String routeId){return service.routeStops(routeId);}
    @GetMapping("/stops") public Page<StopDto> stops(@PageableDefault(size=50,sort="id") Pageable pageable){return service.listStops(pageable);}
}
