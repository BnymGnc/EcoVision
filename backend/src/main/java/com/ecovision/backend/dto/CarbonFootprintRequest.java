package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record CarbonFootprintRequest(
        // Optional consumption entries can exceed the original survey range.
        // The reward remains fixed and claimable only once per account.
        @Min(0) @Max(50000000) int score
) {
}
