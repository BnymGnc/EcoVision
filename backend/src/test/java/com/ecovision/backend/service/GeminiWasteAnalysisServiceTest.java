package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
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

    @Test
    void usesCurrentVisionModelByDefault() {
        assertEquals(
                List.of(
                        "gemini-3.6-flash",
                        "gemini-3.5-flash",
                        "gemini-2.5-flash",
                        "gemini-2.5-flash-lite"
                ),
                GeminiWasteAnalysisService.resolveModelCandidates("")
        );
    }

    @Test
    void normalizesConfiguredModelAndKeepsStableFallbacks() {
        assertEquals(
                List.of(
                        "legacy-render-model",
                        "gemini-3.6-flash",
                        "gemini-3.5-flash",
                        "gemini-2.5-flash",
                        "gemini-2.5-flash-lite"
                ),
                GeminiWasteAnalysisService.resolveModelCandidates(
                        " models/legacy-render-model "
                )
        );
    }

    private GeminiWasteAnalysisService service(String apiKey) {
        return new GeminiWasteAnalysisService(
                new ObjectMapper(),
                apiKey,
                GeminiWasteAnalysisService.DEFAULT_MODEL,
                5000,
                30000
        );
    }
}
