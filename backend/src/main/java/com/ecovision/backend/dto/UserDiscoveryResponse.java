package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Friendship;

public record UserDiscoveryResponse(
        Long id,
        String username,
        String fullName,
        String profilePictureUrl,
        String city,
        Integer avatarLevel,
        String profileVisibility,
        Long friendshipId,
        String friendshipStatus
) {
    public static UserDiscoveryResponse from(AppUser user, Friendship friendship) {
        return new UserDiscoveryResponse(
                user.getId(),
                user.getPublicUsername(),
                (user.getName() + " " + user.getSurname()).trim(),
                user.getProfilePictureUrl(),
                user.getCity(),
                user.getEquippedAvatarLevel(),
                user.getProfileVisibility().name(),
                friendship == null ? null : friendship.getId(),
                friendship == null ? null : friendship.getStatus().name()
        );
    }
}
