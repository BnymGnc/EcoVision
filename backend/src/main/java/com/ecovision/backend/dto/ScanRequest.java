package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ScanRequest(
        @NotBlank @jakarta.validation.constraints.Size(max=100) String materialType,
        @NotNull Boolean recyclable
) {
}
