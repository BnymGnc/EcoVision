package com.ecovision.backend.dto;

import com.ecovision.backend.model.Event;
import java.time.Instant;

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
        Integer memberLimit,
        long memberCount,
        boolean privateGroup,
        String currentUserRole
) {
    public static EventResponse from(Event event) {
        return from(event, 0, null);
    }

    public static EventResponse from(Event event, long memberCount, String currentUserRole) {
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
                event.getMemberLimit(),
                memberCount,
                event.isPrivateGroup(),
                currentUserRole
        );
    }
}
