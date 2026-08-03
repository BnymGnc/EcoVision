package com.ecovision.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record RegisterRequest(
        @NotBlank @Size(max = 60)
        @Pattern(regexp = "^[\\p{L} .'-]+$", message = "geçersiz karakter içeriyor")
        String name,
        @NotBlank @Size(max = 60)
        @Pattern(regexp = "^[\\p{L} .'-]+$", message = "geçersiz karakter içeriyor")
        String surname,
        @Email @NotBlank @Size(max = 254) String email,
        @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z0-9\\s]).{8,72}$",
                message = "8-72 karakter, büyük/küçük harf, rakam ve özel karakter içermelidir"
        )
        String password,
        @NotNull @Past LocalDate dateOfBirth,
        @NotBlank @Size(max = 60) String city,
        @NotBlank @Size(max = 60) String district,
        @Pattern(
                regexp = "^[a-z0-9_]{3,30}$",
                message = "3-30 karakter olmalı ve yalnızca küçük harf, rakam veya alt çizgi içermelidir"
        )
        String username,
        @AssertTrue(message = "kabul edilmelidir") boolean termsAccepted,
        @AssertTrue(message = "kabul edilmelidir") boolean privacyAccepted
) {
}
