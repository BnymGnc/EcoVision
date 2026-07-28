package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.server.ResponseStatusException;

class GeminiWasteAnalysisServiceTest {
    @Test
    void missingApiKeyDoesNotPreventServiceConstruction() {
        assertDoesNotThrow(() -> service(""));
    }

    @Test
    void missingApiKeyReturnsControlledServiceUnavailable() {
        GeminiWasteAnalysisService service = service("");
        MockMultipartFile image = new MockMultipartFile(
                "image",
                "waste.jpg",
                "image/jpeg",
                new byte[]{1, 2, 3}
        );

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> service.analyze(image)
        );

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, exception.getStatusCode());
    }

    private GeminiWasteAnalysisService service(String apiKey) {
        return new GeminiWasteAnalysisService(
                new ObjectMapper(),
                apiKey,
                "gemini-2.5-flash-lite",
                5000,
                30000
        );
    }
}
