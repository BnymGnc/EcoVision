package com.ecovision.backend.dto;

import java.time.Instant;

public record TypingEventResponse(
        Long groupId,
        Long userId,
        String username,
        String fullName,
        boolean typing,
        Instant expiresAt
) {
}
