package com.ecovision.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank String name,
        @NotBlank String surname,
        @Email @NotBlank String email,
        @Pattern(
                regexp = "^(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*(),.?\\\":{}|<>_\\-+=;]).{8,}$",
                message = "must be at least 8 characters and include uppercase, number, and special character"
        )
        @Size(min = 6) String password,
        @Min(1) Integer age
) {
}
