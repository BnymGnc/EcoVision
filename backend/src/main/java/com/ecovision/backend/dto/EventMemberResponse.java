package com.ecovision.backend.dto;

import com.ecovision.backend.model.EventMember;

public record EventMemberResponse(
        Long userId,
        String fullName,
        String role,
        Integer avatarLevel,
        String profilePictureUrl
) {
    public static EventMemberResponse from(EventMember member) {
        return new EventMemberResponse(
                member.getUser().getId(),
                member.getUser().getName() + " " + member.getUser().getSurname(),
                member.getRole().name(),
                member.getUser().getEquippedAvatarLevel(),
                member.getUser().getProfilePictureUrl()
        );
    }
}
