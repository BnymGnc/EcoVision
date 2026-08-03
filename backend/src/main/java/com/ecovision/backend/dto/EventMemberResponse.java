package com.ecovision.backend.dto;

import com.ecovision.backend.model.EventMember;
import com.ecovision.backend.model.AvatarTier;

public record EventMemberResponse(
        Long userId,
        String username,
        String fullName,
        String role,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profilePictureUrl,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
) {
    public static EventMemberResponse from(EventMember member) {
        return new EventMemberResponse(
                member.getUser().getId(),
                member.getUser().getPublicUsername(),
                member.getUser().getName() + " " + member.getUser().getSurname(),
                member.getRole().name(),
                member.getUser().getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(
                        member.getUser().getLifetimePoints()
                ).level(),
                ProfileImageDtoPolicy.publicCustomPhoto(member.getUser()),
                member.getUser().getProfileImagePreference().name(),
                member.getUser().getSelectedAvatarPath(),
                member.getUser().isAdult(),
                member.getUser().getProfileVisibility().name()
        );
    }
}
