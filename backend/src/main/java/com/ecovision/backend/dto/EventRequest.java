package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record EventRequest(
        @NotBlank String title,
        @NotBlank String description,
        @NotBlank String location,
        @NotNull Instant eventDate,
        String imageUrl
) {
}
