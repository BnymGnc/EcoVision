package com.ecovision.backend.dto;

import java.util.List;

public record PublicProfileResponse(
        Long id, String username, String fullName, String profilePictureUrl, String city,
        Integer avatarLevel, Integer totalPoints, Integer lifetimePoints,
        Integer streakCount, long likeCount, boolean likedByCurrentUser,
        String friendshipStatus, Long friendshipId, boolean blockedByCurrentUser,
        String profileVisibility, boolean detailsVisible,
        List<BadgeResponse> badges
) {}
