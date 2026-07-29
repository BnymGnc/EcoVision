package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupJoinRequest;
import java.time.Instant;

public record GroupJoinRequestResponse(
        Long id,
        Long groupId,
        Long userId,
        String username,
        String fullName,
        String profilePictureUrl,
        String status,
        Instant requestedAt
) {
    public static GroupJoinRequestResponse from(GroupJoinRequest request) {
        return new GroupJoinRequestResponse(
                request.getId(),
                request.getGroup().getId(),
                request.getRequester().getId(),
                request.getRequester().getPublicUsername(),
                request.getRequester().getName() + " " + request.getRequester().getSurname(),
                request.getRequester().getProfilePictureUrl(),
                request.getStatus().name(),
                request.getRequestedAt()
        );
    }
}
