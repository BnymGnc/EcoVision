package com.ecovision.backend.controller;

import java.time.Instant;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/health")
public class HealthController {
    private final boolean geminiConfigured;

    public HealthController(
            @Value("${gemini.api.key:}") String geminiApiKey
    ) {
        this.geminiConfigured = geminiApiKey != null
                && !geminiApiKey.isBlank();
    }

    @GetMapping
    public Map<String, Object> health() {
        return Map.of(
                "status", "UP",
                "timestamp", Instant.now(),
                "geminiConfigured", geminiConfigured
        );
    }
}
