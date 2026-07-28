package com.ecovision.backend.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record GroupEventRequest(
        @NotBlank @Size(max = 140) String title,
        @NotBlank @Size(max = 2000) String description,
        @NotNull @Future Instant eventDate,
        @NotBlank @Size(max = 80) String city,
        @NotBlank @Size(max = 80) String district,
        @NotBlank @Size(max = 500) String exactAddress,
        @Min(2) @Max(500) Integer capacity
) {
}
