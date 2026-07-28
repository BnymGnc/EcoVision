package com.ecovision.backend.dto;

import com.ecovision.backend.model.Event;
import java.time.Instant;
import java.time.LocalTime;

public record EventResponse(
        Long id,
        Long creatorId,
        Long adminId,
        String creatorName,
        String title,
        String description,
        String location,
        String city,
        String district,
        String neighborhood,
        Instant eventDate,
        LocalTime eventTime,
        String exactAddress,
        String coverImageUrl,
        Integer memberLimit,
        long memberCount,
        long attendeeCount,
        boolean privateGroup,
        String currentUserRole,
        String currentUserAttendance
) {
    public static EventResponse from(Event event) {
        return from(event, 0, 0, null, null);
    }

    public static EventResponse from(
            Event event,
            long memberCount,
            long attendeeCount,
            String currentUserRole,
            String currentUserAttendance
    ) {
        return new EventResponse(
                event.getId(),
                event.getCreator().getId(),
                event.getCreator().getId(),
                event.getCreator().getName() + " " + event.getCreator().getSurname(),
                event.getTitle(),
                event.getDescription(),
                event.getLocation(),
                event.getCity(),
                event.getDistrict(),
                event.getNeighborhood(),
                event.getEventDate(),
                event.getEventTime(),
                event.getExactAddress(),
                event.getCoverImageUrl(),
                event.getMemberLimit(),
                memberCount,
                attendeeCount,
                event.isPrivateGroup(),
                currentUserRole,
                currentUserAttendance
        );
    }
}
