package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ThemePreferenceRequest(
        @NotBlank
        @Pattern(
                regexp = "forest|ocean|sunset|darkEco",
                message = "Desteklenmeyen tema tercihi"
        )
        String themePreference
) {
}
