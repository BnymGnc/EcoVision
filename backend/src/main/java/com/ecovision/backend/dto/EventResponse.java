package com.ecovision.backend.dto;

import com.ecovision.backend.model.Event;
import java.time.Instant;

public record EventResponse(
        Long id,
        Long creatorId,
        String creatorName,
        String title,
        String description,
        String location,
        Instant eventDate,
        String imageUrl
) {
    public static EventResponse from(Event event) {
        return new EventResponse(
                event.getId(),
                event.getCreator().getId(),
                event.getCreator().getName() + " " + event.getCreator().getSurname(),
                event.getTitle(),
                event.getDescription(),
                event.getLocation(),
                event.getEventDate(),
                event.getImageUrl()
        );
    }
}
