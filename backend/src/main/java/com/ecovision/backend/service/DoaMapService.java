package com.ecovision.backend.service;

import com.ecovision.backend.config.RvmDataLoader;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DoaMapService {
    private final MapPinRepository pins;
    private final ObjectMapper mapper;
    public DoaMapService(MapPinRepository pins, ObjectMapper mapper) { this.pins = pins; this.mapper = mapper; }

    public List<Point> nearby(double lat, double lng, Double radius, Integer limit,
                               Set<String> materials, Set<String> types, boolean openOnly,
                               Double south, Double north, Double west, Double east) {
        validateCoordinate(lat, lng);
        if (radius != null && (!Double.isFinite(radius) || radius < 1 || radius > 2000))
            throw new IllegalArgumentException("Arama yarıçapı 1-2000 km olmalıdır");
        int cap = limit == null ? 500 : limit;
        if (cap < 1 || cap > 1000) throw new IllegalArgumentException("Sonuç sınırı 1-1000 olmalıdır");
        if (south != null || north != null || west != null || east != null) {
            if (south == null || north == null || west == null || east == null)
                throw new IllegalArgumentException("Harita sınırlarının tamamı gereklidir");
            validateCoordinate(south, west); validateCoordinate(north, east);
            if (south > north || west > east) throw new IllegalArgumentException("Harita sınırları geçersiz");
        } else if (radius != null) {
            double dy = radius / 111.0;
            double dx = radius / (111.0 * Math.max(0.01, Math.cos(Math.toRadians(lat))));
            south = Math.max(-90, lat - dy); north = Math.min(90, lat + dy);
            west = Math.max(-180, lng - dx); east = Math.min(180, lng + dx);
        } else { south = -90.0; north = 90.0; west = -180.0; east = 180.0; }
        Set<String> normalized = new HashSet<>();
        materials.forEach(m -> normalized.add(RvmDataLoader.normalizeMaterial(m)));
        if (!Set.of("pet", "glass", "aluminum").containsAll(normalized))
            throw new IllegalArgumentException("Malzeme PET, cam veya alüminyum olmalıdır");
        Set<String> pointTypes = new HashSet<>();
        types.forEach(type -> pointTypes.add(type.toUpperCase(Locale.ROOT)));
        if (!Set.of("DIM", "MIN", "KIM", "SDM", "UNKNOWN").containsAll(pointTypes))
            throw new IllegalArgumentException("Nokta türü geçersiz");
        Instant now = Instant.now();
        return pins.findPointSummaries(south, north, west, east).stream()
                .filter(p -> pointTypes.isEmpty() || pointTypes.contains(p.getPointType()))
                .map(p -> toPoint(p, lat, lng, now))
                .filter(p -> radius == null || p.distanceKm() <= radius)
                .filter(p -> normalized.isEmpty() || normalized.stream().anyMatch(p.acceptedMaterials()::contains))
                .filter(p -> !openOnly || p.scheduleStatus().equals("OPEN"))
                .sorted(Comparator.comparingDouble(Point::distanceKm).thenComparing(Point::id))
                .limit(cap).toList();
    }

    @Transactional(readOnly = true)
    public Detail detail(Long id) {
        MapPin pin = pins.findById(id).orElseThrow(() -> new IllegalArgumentException("İade noktası bulunamadı"));
        return new Detail(pin.getId(), pin.getTitle(), pin.getAddress(), pin.getPointType(),
                pin.getAcceptedMaterials(), json(pin.getRawBinsJson()), json(pin.getWeeklyScheduleJson()),
                PointSchedule.status(pin.getWeeklyScheduleJson(), Instant.now()), pin.getSnapshotAt(),
                pin.getImportedAt(), pin.getTelemetryObservedAt(), pin.getSourceUrl(),
                pin.getSourceActiveRaw(), pin.getSourceStatusRaw(), pin.getSourceMachineStatusRaw(),
                json(pin.getDataQualityFlags()));
    }

    private Point toPoint(MapPinRepository.PointSummary p, double lat, double lng, Instant now) {
        Set<String> materials = new LinkedHashSet<>();
        Map<String, Boolean> states = new LinkedHashMap<>();
        JsonNode bins = json(p.getRawBinsJson());
        for (JsonNode bin : bins) {
            String code = bin.path("contentType").asText(bin.path("type").asText(""));
            if (!code.isBlank()) {
                materials.add(RvmDataLoader.normalizeMaterial(code));
                if (bin.hasNonNull("state")) states.put(RvmDataLoader.normalizeMaterial(code), bin.get("state").asBoolean());
            }
        }
        for (JsonNode code : json(p.getSourceMaterialCodesJson())) {
            if (!code.asText().equals("can")) materials.add(RvmDataLoader.normalizeMaterial(code.asText()));
        }
        return new Point(p.getId(), p.getTitle(), p.getLatitude(), p.getLongitude(), p.getAddress(),
                p.getPointType(), materials, states, distance(lat, lng, p.getLatitude(), p.getLongitude()),
                PointSchedule.status(p.getWeeklyScheduleJson(), now), p.getSnapshotAt());
    }
    private JsonNode json(String value) {
        try { return mapper.readTree(value == null ? "[]" : value); }
        catch (Exception ignored) { return mapper.createArrayNode(); }
    }
    static void validateCoordinate(double lat, double lng) {
        if (!Double.isFinite(lat) || !Double.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180)
            throw new IllegalArgumentException("Koordinatlar geçersiz");
    }
    public static double distance(double lat, double lng, double lat2, double lng2) {
        double a = Math.pow(Math.sin(Math.toRadians(lat2 - lat) / 2), 2)
                + Math.cos(Math.toRadians(lat)) * Math.cos(Math.toRadians(lat2))
                * Math.pow(Math.sin(Math.toRadians(lng2 - lng) / 2), 2);
        return 6371 * 2 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, a))));
    }
    public record Point(Long id, String title, double latitude, double longitude, String address,
                        String pointType, Set<String> acceptedMaterials, Map<String, Boolean> binStates,
                        double distanceKm, String scheduleStatus, Instant snapshotAt) {}
    public record Detail(Long id, String title, String address, String pointType, Set<String> acceptedMaterials,
                         JsonNode binList, JsonNode weeklySchedule, String scheduleStatus, Instant snapshotAt,
                         Instant importedAt, Instant telemetryObservedAt, String sourceUrl, Boolean sourceActiveRaw,
                         Integer sourceStatusRaw, Integer sourceMachineStatusRaw, JsonNode dataQualityFlags) {}
}
