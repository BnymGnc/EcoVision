package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record MapPinRequest(
        @NotBlank String title,
        @NotNull Double latitude,
        @NotNull Double longitude
) {
}
