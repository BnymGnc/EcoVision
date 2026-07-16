package com.ecovision.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record GoogleAuthRequest(
        @NotBlank String idToken,
        @Email @NotBlank String email,
        String name,
        String surname,
        String profilePictureUrl
) {
}
