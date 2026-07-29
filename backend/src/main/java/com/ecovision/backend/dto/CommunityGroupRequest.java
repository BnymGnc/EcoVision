package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CommunityGroupRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 2000) String description,
        @NotBlank @Size(max = 80) String city,
        @NotBlank @Size(max = 80) String district,
        @Size(max = 120) String neighborhood,
        @Min(2) @Max(200) Integer memberLimit,
        @Size(max = 64) String joinCode,
        Boolean privateGroup
) {
}
