package com.ecovision.backend.dto;

import java.util.Set;

public record GamificationResponse(
        int totalPoints,
        boolean carbonFootprintCompleted,
        Set<String> redeemedRewardKeys,
        int pointsAwarded,
        String badge,
        String message
) {
}
