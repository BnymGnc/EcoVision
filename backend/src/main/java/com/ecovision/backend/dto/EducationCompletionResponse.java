package com.ecovision.backend.dto;

public record EducationCompletionResponse(
        String categoryId,
        boolean newlyCompleted,
        int pointsAwarded,
        int totalPoints,
        String message
) {
}
