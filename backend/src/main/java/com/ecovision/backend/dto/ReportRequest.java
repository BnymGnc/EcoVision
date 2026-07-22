package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ReportRequest(
        @NotBlank @Size(max = 80) String reason,
        @Size(max = 1000) String details
) {}
