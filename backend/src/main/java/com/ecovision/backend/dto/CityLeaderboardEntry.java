package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;

public record CityLeaderboardEntry(
        int rank,
        Long userId,
        String fullName,
        String city,
        Integer totalPoints,
        String profilePictureUrl,
        boolean currentUser
) {
    public static CityLeaderboardEntry from(
            AppUser user,
            int rank,
            Long currentUserId
    ) {
        return new CityLeaderboardEntry(
                rank,
                user.getId(),
                (user.getName() + " " + user.getSurname()).trim(),
                user.getCity(),
                user.getTotalPoints(),
                user.getProfilePictureUrl(),
                user.getId().equals(currentUserId)
        );
    }
}
