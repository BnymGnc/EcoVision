package com.ecovision.backend.service;

import com.ecovision.backend.dto.MapPinResponse;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class OverpassMapPinService {
    private static final Logger LOGGER = LoggerFactory.getLogger(OverpassMapPinService.class);
    private static final String OVERPASS_URL = "https://overpass-api.de/api/interpreter";

    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public OverpassMapPinService(ObjectMapper objectMapper) {
        this.restClient = RestClient.builder()
                .defaultHeader("User-Agent", "EcoVision-MVP/1.0")
                .build();
        this.objectMapper = objectMapper;
    }

    public List<MapPinResponse> findNearest(
            double latitude,
            double longitude,
            Double radiusKm,
            Integer limit
    ) {
        int radiusMeters = (int) Math.round((radiusKm == null ? 5.0 : radiusKm) * 1000);
        int safeLimit = limit == null || limit <= 0 ? 20 : Math.min(limit, 50);
        String query = """
                [out:json][timeout:8];
                (
                  node["amenity"="recycling"](around:%d,%f,%f);
                  node["amenity"="waste_basket"](around:%d,%f,%f);
                  node["recycling_type"](around:%d,%f,%f);
                );
                out tags;
                """.formatted(
                radiusMeters,
                latitude,
                longitude,
                radiusMeters,
                latitude,
                longitude,
                radiusMeters,
                latitude,
                longitude
        );

        try {
            String response = restClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .scheme("https")
                            .host("overpass-api.de")
                            .path("/api/interpreter")
                            .queryParam("data", query)
                            .build())
                    .retrieve()
                    .body(String.class);
            return parse(response, latitude, longitude, safeLimit);
        } catch (RuntimeException exception) {
            LOGGER.warn("OpenStreetMap Overpass fallback failed", exception);
            return List.of();
        }
    }

    private List<MapPinResponse> parse(
            String response,
            double latitude,
            double longitude,
            int limit
    ) {
        try {
            JsonNode elements = objectMapper.readTree(response).path("elements");
            List<MapPinResponse> pins = new ArrayList<>();
            Instant now = Instant.now();

            for (JsonNode element : elements) {
                if (!element.hasNonNull("lat") || !element.hasNonNull("lon")) {
                    continue;
                }

                double pinLat = element.path("lat").asDouble();
                double pinLng = element.path("lon").asDouble();
                JsonNode tags = element.path("tags");
                String amenity = tags.path("amenity").asText();
                String title = tags.path("name").asText();
                if (title.isBlank()) {
                    title = "waste_basket".equals(amenity)
                            ? "Public Waste Basket"
                            : "Recycling Point";
                }

                String type = "waste_basket".equals(amenity)
                        ? "OPENSTREETMAP_WASTE_BASKET"
                        : "OPENSTREETMAP_RECYCLING_BIN";
                double distanceKm = haversineKm(latitude, longitude, pinLat, pinLng);

                pins.add(MapPinResponse.external(
                        -Math.abs(element.path("id").asLong()),
                        title,
                        pinLat,
                        pinLng,
                        type,
                        "OpenStreetMap",
                        now,
                        distanceKm
                ));
            }

            return pins.stream()
                    .sorted(Comparator.comparing(MapPinResponse::distanceKm))
                    .limit(limit)
                    .toList();
        } catch (RuntimeException | java.io.IOException exception) {
            LOGGER.warn("Could not parse Overpass response", exception);
            return List.of();
        }
    }

    private double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2)
                * Math.sin(dLon / 2);
        return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
