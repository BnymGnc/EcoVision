package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;

public record SocialUserResponse(
        Long id, String username, String fullName, String profilePictureUrl, String city,
        Integer avatarLevel, Long friendshipId
) {
    public static SocialUserResponse from(AppUser user, Long friendshipId) {
        return new SocialUserResponse(user.getId(), user.getPublicUsername(),
                user.getName() + " " + user.getSurname(),
                user.getProfilePictureUrl(), user.getCity(), user.getEquippedAvatarLevel(), friendshipId);
    }
}
