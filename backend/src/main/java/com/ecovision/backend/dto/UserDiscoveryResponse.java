package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.Friendship;
import com.ecovision.backend.model.FriendshipStatus;
import com.ecovision.backend.model.ProfileVisibility;
import com.ecovision.backend.model.ProfileImagePreference;

public record UserDiscoveryResponse(
        Long id,
        String username,
        String fullName,
        String profilePictureUrl,
        String city,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
        Long friendshipId,
        String friendshipStatus
) {
    public static UserDiscoveryResponse from(AppUser user, Friendship friendship) {
        boolean acceptedFriend = friendship != null
                && friendship.getStatus() == FriendshipStatus.ACCEPTED;
        String visiblePhoto = user.isAdult()
                && user.getProfileImagePreference()
                == ProfileImagePreference.CUSTOM_PHOTO
                && (user.getProfileVisibility() == ProfileVisibility.PUBLIC
                || acceptedFriend)
                ? user.getProfilePictureUrl()
                : null;
        return new UserDiscoveryResponse(
                user.getId(),
                user.getPublicUsername(),
                (user.getName() + " " + user.getSurname()).trim(),
                visiblePhoto,
                user.getCity(),
                user.getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(user.getLifetimePoints()).level(),
                user.getProfileImagePreference().name(),
                user.getSelectedAvatarPath(),
                user.isAdult(),
                user.getProfileVisibility().name(),
                friendship == null ? null : friendship.getId(),
                friendship == null ? null : friendship.getStatus().name()
        );
    }
}
