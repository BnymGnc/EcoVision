package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record CarbonFootprintRequest(
        @Min(0) @Max(30000) int score
) {
}
