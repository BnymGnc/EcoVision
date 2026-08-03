package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.ProfileImagePreference;
import com.ecovision.backend.model.ProfileVisibility;

public record CityLeaderboardEntry(
        int rank,
        Long userId,
        String username,
        String fullName,
        String city,
        Integer totalPoints,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
        String friendshipStatus,
        boolean currentUser
) {
    public static CityLeaderboardEntry from(
            AppUser user,
            int rank,
            Long currentUserId,
            boolean acceptedFriend
    ) {
        boolean ownProfile = user.getId().equals(currentUserId);
        String visiblePhoto = user.isAdult()
                && user.getProfileImagePreference()
                == ProfileImagePreference.CUSTOM_PHOTO
                && (ownProfile
                || user.getProfileVisibility() == ProfileVisibility.PUBLIC
                || acceptedFriend)
                ? user.getProfilePictureUrl()
                : null;
        return new CityLeaderboardEntry(
                rank,
                user.getId(),
                user.getPublicUsername(),
                (user.getName() + " " + user.getSurname()).trim(),
                user.getCity(),
                user.getTotalPoints(),
                visiblePhoto,
                user.getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(user.getLifetimePoints()).level(),
                user.getProfileImagePreference().name(),
                user.getSelectedAvatarPath(),
                user.isAdult(),
                user.getProfileVisibility().name(),
                acceptedFriend ? "ACCEPTED" : null,
                ownProfile
        );
    }
}
