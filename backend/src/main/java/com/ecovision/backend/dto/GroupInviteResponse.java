package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupInvite;
import java.time.Instant;

public record GroupInviteResponse(
        Long id, Long eventId, String eventTitle, String location,
        SocialUserResponse inviter, String status, Instant createdAt
) {
    public static GroupInviteResponse from(GroupInvite invite) {
        return new GroupInviteResponse(invite.getId(), invite.getEvent().getId(),
                invite.getEvent().getTitle(), invite.getEvent().getLocation(),
                SocialUserResponse.from(invite.getInviter(), null),
                invite.getStatus().name(), invite.getCreatedAt());
    }
}
