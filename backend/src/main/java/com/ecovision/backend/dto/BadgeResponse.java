package com.ecovision.backend.dto;

import com.ecovision.backend.model.UserBadge;
import java.time.Instant;

public record BadgeResponse(String type, String title, String description, Instant awardedAt) {
    public static BadgeResponse from(UserBadge badge) {
        return new BadgeResponse(
                badge.getBadgeType().name(),
                badge.getBadgeType().title(),
                badge.getBadgeType().description(),
                badge.getAwardedAt()
        );
    }
}
