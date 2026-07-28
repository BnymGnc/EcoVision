package com.ecovision.backend.dto;

public record QuestClaimResponse(
        QuestProgressResponse quest,
        int pointsAwarded,
        int totalPoints,
        String message
) {
}
