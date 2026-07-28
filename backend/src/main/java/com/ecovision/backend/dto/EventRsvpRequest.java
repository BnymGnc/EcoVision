package com.ecovision.backend.dto;

import com.ecovision.backend.model.AttendanceStatus;
import jakarta.validation.constraints.NotNull;

public record EventRsvpRequest(@NotNull AttendanceStatus status) {
}
