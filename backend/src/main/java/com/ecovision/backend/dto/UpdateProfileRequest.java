package com.ecovision.backend.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record UpdateProfileRequest(
        @NotBlank String name,
        @NotBlank String surname,
        @Min(1) Integer age,
        @NotBlank String city,
        @NotBlank String district,
        @NotBlank String neighborhood
) {
}
