package com.ecovision.backend.dto;

import com.ecovision.backend.model.AvatarTier;

public record AvatarTierResponse(
        int level,
        String title,
        int requiredLifetimePoints,
        boolean unlocked,
        boolean equipped
) {
    public static AvatarTierResponse from(AvatarTier tier, int lifetimePoints, int equippedLevel) {
        return new AvatarTierResponse(
                tier.level(),
                tier.title(),
                tier.requiredLifetimePoints(),
                lifetimePoints >= tier.requiredLifetimePoints(),
                equippedLevel == tier.level()
        );
    }
}
