package com.ecovision.backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class HealthControllerTest {

    @Test
    void healthReturnsKeepAliveMessage() {
        HealthController controller = new HealthController();

        assertEquals("EcoVision Backend is awake!", controller.health());
    }

    @Test
    void livenessSupportsGetAndHeadWithoutDependencies() throws Exception {
        var mvc = MockMvcBuilders.standaloneSetup(new HealthController()).build();
        for (String path : new String[]{"/api/health", "/api/health/live"}) {
            mvc.perform(get(path)).andExpect(status().isOk())
                    .andExpect(content().string("EcoVision Backend is awake!"));
            mvc.perform(head(path)).andExpect(status().isOk())
                    .andExpect(content().string(""));
        }
    }
}
