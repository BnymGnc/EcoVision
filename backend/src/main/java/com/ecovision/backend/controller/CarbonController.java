package com.ecovision.backend.controller;

import com.ecovision.backend.service.*;
import java.util.*;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/carbon")
public class CarbonController {
    private final CarbonService service;
    private final CurrentUserService current;
    public CarbonController(CarbonService service, CurrentUserService current) { this.service = service; this.current = current; }
    @PostMapping("/assessments") public Map<String, Object> assess(@RequestBody CarbonMath.Inputs request) throws Exception {
        return service.assess(current.currentUser(), request);
    }
    @GetMapping("/assessments") public List<Map<String, Object>> assessments() { return service.history(current.currentUser()); }
    @GetMapping("/actions") public List<CarbonService.ActionResponse> actions() { return service.actions(current.currentUser()); }
    @PostMapping("/actions") public CarbonService.ActionResponse action(@RequestBody CarbonService.ActionRequest request) {
        return service.saveAction(current.currentUser(), request);
    }
    @DeleteMapping("/actions/{id}") public void delete(@PathVariable Long id) { service.deleteAction(current.currentUser(), id); }
    @PutMapping("/actions/{id}") public CarbonService.ActionResponse updateMass(@PathVariable Long id, @RequestBody MassUpdate request) {
        return service.updateMass(current.currentUser(), id, request.massKg());
    }
    public record MassUpdate(double massKg) {}
    @GetMapping("/summary") public CarbonService.Summary summary() { return service.summary(current.currentUser()); }
}
