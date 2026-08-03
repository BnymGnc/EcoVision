package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.ProfileImagePreference;
import com.ecovision.backend.model.ProfileVisibility;

public record SocialUserResponse(
        Long id, String username, String fullName, String profilePictureUrl, String city,
        Integer avatarLevel, Integer highestAvatarLevel,
        String profileImagePreference, String selectedAvatarPath, boolean adult,
        String profileVisibility, Long friendshipId, String friendshipStatus
) {
    public static SocialUserResponse from(
            AppUser user,
            Long friendshipId,
            String friendshipStatus
    ) {
        boolean acceptedFriend = "ACCEPTED".equals(friendshipStatus);
        String visiblePhoto = user.isAdult()
                && user.getProfileImagePreference()
                == ProfileImagePreference.CUSTOM_PHOTO
                && (user.getProfileVisibility() == ProfileVisibility.PUBLIC
                || acceptedFriend)
                ? user.getProfilePictureUrl()
                : null;
        return new SocialUserResponse(user.getId(), user.getPublicUsername(),
                user.getName() + " " + user.getSurname(),
                visiblePhoto, user.getCity(), user.getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(user.getLifetimePoints()).level(),
                user.getProfileImagePreference().name(),
                user.getSelectedAvatarPath(), user.isAdult(),
                user.getProfileVisibility().name(), friendshipId, friendshipStatus);
    }
}
