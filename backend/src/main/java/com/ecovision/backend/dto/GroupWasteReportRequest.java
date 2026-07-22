package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record GroupWasteReportRequest(
        @NotBlank String materialType,
        @Min(1) @Max(100_000) int itemCount
) {
}
