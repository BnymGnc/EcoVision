package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record PinGroupContentRequest(
        @NotBlank
        @Pattern(regexp = "MESSAGE|EVENT|NONE")
        String type,
        Long id
) {
}
