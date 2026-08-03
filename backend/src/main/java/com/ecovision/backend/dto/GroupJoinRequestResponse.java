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
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
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
                ProfileImageDtoPolicy.publicCustomPhoto(request.getRequester()),
                request.getRequester().getEquippedAvatarLevel(),
                com.ecovision.backend.model.AvatarTier.highestUnlocked(
                        request.getRequester().getLifetimePoints()
                ).level(),
                request.getRequester().getProfileImagePreference().name(),
                request.getRequester().getSelectedAvatarPath(),
                request.getRequester().isAdult(),
                request.getRequester().getProfileVisibility().name(),
                request.getStatus().name(),
                request.getRequestedAt()
        );
    }
}
