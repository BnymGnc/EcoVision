package com.ecovision.backend.dto;

import com.ecovision.backend.model.MapPin;
import java.time.Instant;
import java.util.List;
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
        Set<String> acceptedMaterials,
        Map<String, Boolean> binStates,
        List<MapPinBinResponse> binList,
        boolean active
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
                pin.currentlyAcceptedMaterials(),
                currentBinStates(pin),
                pin.getBinList().stream()
                        .map(MapPinBinResponse::from)
                        .toList(),
                pin.isActive()
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
                Set.of(),
                Map.of(),
                List.of(),
                true
        );
    }

    private static Map<String, Boolean> currentBinStates(MapPin pin) {
        return Map.of(
                "pet", pin.acceptsMaterial("pet"),
                "glass", pin.acceptsMaterial("glass"),
                "aluminum", pin.acceptsMaterial("aluminum")
        );
    }
}
