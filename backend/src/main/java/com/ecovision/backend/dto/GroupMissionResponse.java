package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupMission;
import java.time.Instant;

public record GroupMissionResponse(
        Long id,
        Long eventId,
        String title,
        Integer targetAmount,
        Integer currentAmount,
        String unit,
        Instant createdAt
) {
    public static GroupMissionResponse from(GroupMission mission) {
        return new GroupMissionResponse(
                mission.getId(),
                mission.getEvent().getId(),
                mission.getTitle(),
                mission.getTargetAmount(),
                mission.getCurrentAmount(),
                mission.getUnit(),
                mission.getCreatedAt()
        );
    }
}
