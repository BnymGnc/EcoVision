package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.AvatarTier;

public record GroupMemberResponse(
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
    public static GroupMemberResponse from(GroupMember member) {
        return from(member, member.getRole().name());
    }

    public static GroupMemberResponse from(GroupMember member, String role) {
        return new GroupMemberResponse(
                member.getUser().getId(),
                member.getUser().getPublicUsername(),
                member.getUser().getName() + " " + member.getUser().getSurname(),
                role,
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
