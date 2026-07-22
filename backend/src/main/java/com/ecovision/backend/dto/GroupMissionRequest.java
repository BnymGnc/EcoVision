package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record GroupMissionRequest(
        @NotBlank String title,
        @Min(1) @Max(1_000_000) int targetAmount,
        @NotBlank String unit
) {
}
