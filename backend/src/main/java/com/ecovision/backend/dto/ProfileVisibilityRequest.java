package com.ecovision.backend.dto;

import com.ecovision.backend.model.ProfileVisibility;
import jakarta.validation.constraints.NotNull;

public record ProfileVisibilityRequest(@NotNull ProfileVisibility visibility) {
}
