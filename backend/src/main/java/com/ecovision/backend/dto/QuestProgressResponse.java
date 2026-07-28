package com.ecovision.backend.dto;

import java.time.Instant;

public record QuestProgressResponse(
        Long questId,
        Long progressId,
        String code,
        String title,
        String description,
        int rewardPoints,
        int targetAmount,
        String schedule,
        String domain,
        int currentAmount,
        boolean completed,
        boolean claimed,
        boolean checkInAvailable,
        Instant expiresAt
) {
}
