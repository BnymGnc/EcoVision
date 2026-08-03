package com.ecovision.backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class HealthControllerTest {

    @Test
    void healthReturnsKeepAliveMessage() {
        HealthController controller = new HealthController();

        assertEquals("EcoVision Backend is awake!", controller.health());
    }
}
