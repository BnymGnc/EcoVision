package com.ecovision.backend.dto;

import jakarta.validation.constraints.NotBlank;

public record RewardRedemptionRequest(
        @NotBlank String rewardKey
) {
}
