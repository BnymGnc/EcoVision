package com.ecovision.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

@RestController
public class HealthController {

    // Liveness only: no database, inference, import, or external HTTP work.
    @GetMapping({"/api/health", "/api/health/live"})
    public String health() {
        return "EcoVision Backend is awake!";
    }

    @RequestMapping(value = {"/api/health", "/api/health/live"}, method = RequestMethod.HEAD)
    public void head() {
        // An explicit bodyless route also keeps monitoring clients lightweight.
    }
}
