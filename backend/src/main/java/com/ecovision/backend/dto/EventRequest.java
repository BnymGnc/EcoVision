package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import java.time.Instant;
import java.time.LocalTime;
import jakarta.validation.constraints.Size;

public record EventRequest(
        @NotBlank String title,
        @NotBlank String description,
        @NotBlank String city,
        @NotBlank String district,
        @NotBlank String neighborhood,
        @NotNull Instant eventDate,
        @NotNull LocalTime eventTime,
        @NotBlank @Size(max = 500) String exactAddress,
        @Min(2) @Max(200) Integer memberLimit,
        String joinCode
) {
}
