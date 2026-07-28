package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupEvent;
import java.time.Instant;
import java.util.List;

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
        Integer capacity,
        long attendeeCount,
        String currentUserAttendance,
        List<GroupEventAttendeeResponse> attendees,
        Instant createdAt
) {
    public static GroupEventResponse from(
            GroupEvent event,
            long attendeeCount,
            String currentUserAttendance,
            List<GroupEventAttendeeResponse> attendees
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
                event.getCapacity(),
                attendeeCount,
                currentUserAttendance,
                attendees,
                event.getCreatedAt()
        );
    }
}
