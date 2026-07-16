package com.ecovision.backend.dto;

import com.ecovision.backend.model.MapPin;
import java.time.Instant;

public record MapPinResponse(
        Long id,
        String title,
        Double latitude,
        Double longitude,
        String type,
        Long createdById,
        String createdByName,
        Instant createdAt
) {
    public static MapPinResponse from(MapPin pin) {
        return new MapPinResponse(
                pin.getId(),
                pin.getTitle(),
                pin.getLatitude(),
                pin.getLongitude(),
                pin.getType().name(),
                pin.getCreatedBy().getId(),
                pin.getCreatedBy().getName() + " " + pin.getCreatedBy().getSurname(),
                pin.getCreatedAt()
        );
    }
}
