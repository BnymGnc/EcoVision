package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChatReactionRequest(@NotBlank @Size(max = 12) String emoji) {
}
