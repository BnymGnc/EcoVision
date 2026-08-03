package com.ecovision.backend.dto;

import java.time.Instant;

public record EventTypingEventResponse(
        Long eventId,
        Long userId,
        String username,
        String fullName,
        boolean typing,
        Instant expiresAt
) {
}
