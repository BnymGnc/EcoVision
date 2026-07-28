package com.ecovision.backend.dto;

import com.ecovision.backend.model.MapPin;
import java.time.Instant;
import java.util.Set;
import java.util.Map;

public record MapPinResponse(
        Long id,
        String title,
        Double latitude,
        Double longitude,
        String type,
        Long createdById,
        String createdByName,
        Instant createdAt,
        Double distanceKm,
        String address,
        String workingHours,
        Set<String> acceptedMaterials,
        Map<String, Boolean> binStates,
        boolean active,
        boolean openNow
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
                distanceKm,
                pin.getAddress(),
                pin.getWorkingHours(),
                pin.currentlyAcceptedMaterials(),
                Map.copyOf(pin.getBinStates()),
                pin.isActive(),
                pin.isActive() && com.ecovision.backend.service.MapPinHours.isOpenNow(
                        pin.getWorkingHours()
                )
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
                distanceKm,
                null,
                null,
                Set.of(),
                Map.of(),
                true,
                true
        );
    }
}
