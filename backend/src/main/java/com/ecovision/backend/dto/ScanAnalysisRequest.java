package com.ecovision.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

public record ScanAnalysisRequest(
        @JsonProperty("detected_class")
        @NotBlank
        String detectedClass
) {
}
