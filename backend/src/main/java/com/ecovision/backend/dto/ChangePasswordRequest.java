package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ChangePasswordRequest(
        @NotBlank String currentPassword,
        @Pattern(
                regexp = "^(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*(),.?\\\":{}|<>_\\-+=;]).{8,}$",
                message = "en az 8 karakter, bir büyük harf, bir rakam ve bir özel karakter içermelidir"
        )
        @NotBlank
        String newPassword
) {
}
