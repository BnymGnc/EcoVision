package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupMember;

public record GroupMemberResponse(
        Long userId,
        String username,
        String fullName,
        String role,
        Integer avatarLevel,
        String profilePictureUrl
) {
    public static GroupMemberResponse from(GroupMember member) {
        return new GroupMemberResponse(
                member.getUser().getId(),
                member.getUser().getPublicUsername(),
                member.getUser().getName() + " " + member.getUser().getSurname(),
                member.getRole().name(),
                member.getUser().getEquippedAvatarLevel(),
                member.getUser().getProfilePictureUrl()
        );
    }
}
