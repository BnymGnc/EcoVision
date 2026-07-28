package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AddGroupMemberRequest(
        @NotBlank @Size(max = 40) String username
) {
}
