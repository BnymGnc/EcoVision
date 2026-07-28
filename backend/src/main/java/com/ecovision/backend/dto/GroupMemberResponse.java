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
        return from(member, member.getRole().name());
    }

    public static GroupMemberResponse from(GroupMember member, String role) {
        return new GroupMemberResponse(
                member.getUser().getId(),
                member.getUser().getPublicUsername(),
                member.getUser().getName() + " " + member.getUser().getSurname(),
                role,
                member.getUser().getEquippedAvatarLevel(),
                member.getUser().getProfilePictureUrl()
        );
    }
}
