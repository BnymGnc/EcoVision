package com.ecovision.backend.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateProfileRequest(
        @NotBlank String name,
        @NotBlank String surname,
        @Min(13) Integer age,
        @NotBlank String city,
        @NotBlank String district,
        @NotBlank String neighborhood,
        @Pattern(
                regexp = "^[a-z0-9_]{3,30}$",
                message = "3-30 karakter olmalı ve yalnızca küçük harf, rakam veya alt çizgi içermelidir"
        )
        String username
) {
}
