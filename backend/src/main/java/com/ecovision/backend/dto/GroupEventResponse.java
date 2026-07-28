package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupEvent;
import java.time.Instant;

public record GroupEventResponse(
        Long id,
        Long groupId,
        Long creatorId,
        String creatorName,
        String title,
        String description,
        Instant eventDate,
        String city,
        String district,
        String exactAddress,
        String coverImageUrl,
        long attendeeCount,
        String currentUserAttendance
) {
    public static GroupEventResponse from(
            GroupEvent event,
            long attendeeCount,
            String currentUserAttendance
    ) {
        return new GroupEventResponse(
                event.getId(),
                event.getGroup().getId(),
                event.getCreator().getId(),
                event.getCreator().getName() + " " + event.getCreator().getSurname(),
                event.getTitle(),
                event.getDescription(),
                event.getEventDate(),
                event.getCity(),
                event.getDistrict(),
                event.getExactAddress(),
                event.getCoverImageUrl(),
                attendeeCount,
                currentUserAttendance
        );
    }
}
