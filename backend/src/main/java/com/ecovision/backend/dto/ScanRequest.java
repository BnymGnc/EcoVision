package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ScanRequest(
        @NotBlank String materialType,
        @NotNull Boolean recyclable
) {
}
