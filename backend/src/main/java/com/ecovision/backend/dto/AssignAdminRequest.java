package com.ecovision.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record AssignAdminRequest(@Email @NotBlank String email) {
}
