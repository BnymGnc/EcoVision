package com.ecovision.backend.dto;

import com.ecovision.backend.model.CommunityGroup;
import java.time.Instant;

public record CommunityGroupResponse(
        Long id,
        Long creatorId,
        String creatorName,
        String name,
        String description,
        String city,
        String district,
        String neighborhood,
        String coverImageUrl,
        Integer memberLimit,
        long memberCount,
        boolean privateGroup,
        String currentUserRole,
        Instant createdAt
) {
    public static CommunityGroupResponse from(
            CommunityGroup group,
            long memberCount,
            String currentUserRole
    ) {
        return new CommunityGroupResponse(
                group.getId(),
                group.getCreator().getId(),
                group.getCreator().getName() + " " + group.getCreator().getSurname(),
                group.getName(),
                group.getDescription(),
                group.getCity(),
                group.getDistrict(),
                group.getNeighborhood(),
                group.getCoverImageUrl(),
                group.getMemberLimit(),
                memberCount,
                group.isPrivateGroup(),
                currentUserRole,
                group.getCreatedAt()
        );
    }
}
