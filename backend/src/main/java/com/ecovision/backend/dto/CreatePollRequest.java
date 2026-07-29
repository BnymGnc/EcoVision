package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record CreatePollRequest(
        @NotBlank @Size(max = 300) String question,
        @Size(min = 2, max = 4) List<@NotBlank @Size(max = 160) String> options
) {
}
