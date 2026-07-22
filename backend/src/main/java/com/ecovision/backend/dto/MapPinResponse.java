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
        Instant createdAt,
        Double distanceKm
) {
    public static MapPinResponse from(MapPin pin) {
        return from(pin, null);
    }

    public static MapPinResponse from(MapPin pin, Double distanceKm) {
        return new MapPinResponse(
                pin.getId(),
                pin.getTitle(),
                pin.getLatitude(),
                pin.getLongitude(),
                pin.getType().name(),
                pin.getCreatedBy().getId(),
                pin.getCreatedBy().getName() + " " + pin.getCreatedBy().getSurname(),
                pin.getCreatedAt(),
                distanceKm
        );
    }

    public static MapPinResponse external(
            Long id,
            String title,
            Double latitude,
            Double longitude,
            String type,
            String sourceName,
            Instant createdAt,
            Double distanceKm
    ) {
        return new MapPinResponse(
                id,
                title,
                latitude,
                longitude,
                type,
                0L,
                sourceName,
                createdAt,
                distanceKm
        );
    }
}
