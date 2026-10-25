package com.ecovision.backend.service;

import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.text.Normalizer;
import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

/** Address-derived administrative areas, never inferred from a shop/street name. */
@Service
public class DoaLocationService {
    private final MapPinRepository repository;
    private final Map<String, List<String>> provinces;
    private final Map<String, String> names = new LinkedHashMap<>();
    private final Pattern cityPattern;
    private volatile Index cached;

    public DoaLocationService(MapPinRepository repository, ObjectMapper mapper) throws IOException {
        this.repository = repository;
        try (var input = new ClassPathResource("data/turkey_locations.json").getInputStream()) {
            provinces = mapper.convertValue(mapper.readTree(input).get("provinces"), new TypeReference<>() {});
        }
        provinces.keySet().forEach(city -> names.put(normalize(city), city));
        names.put("icel", "Mersin"); names.put("afyon", "Afyonkarahisar");
        cityPattern = Pattern.compile("(?<![a-z])(" + names.keySet().stream()
                .sorted(Comparator.comparingInt(String::length).reversed()).map(Pattern::quote)
                .collect(java.util.stream.Collectors.joining("|")) + ")(?![a-z])");
    }

    static String normalize(String text) {
        return Normalizer.normalize(Objects.toString(text, "").replace('ı', 'i').replace('İ', 'I')
                .toLowerCase(Locale.ROOT), Normalizer.Form.NFKD).replaceAll("\\p{M}", "");
    }

    public Area resolve(String address) {
        String text = normalize(address);
        var matcher = cityPattern.matcher(text);
        List<int[]> matches = new ArrayList<>();
        while (matcher.find()) matches.add(new int[]{matcher.start(), matcher.end()});
        Collections.reverse(matches);
        for (var match : matches) {
            String city = names.get(text.substring(match[0], match[1]));
            String suffix = text.substring(match[1]).replaceFirst("[, ]*turkiye\\s*$", "").replaceAll("^[ /,.-]+|[ /,.-]+$", "");
            for (String district : provinces.get(city)) {
                if (Pattern.compile("^" + Pattern.quote(normalize(district)) + "(?:$|[^a-z])").matcher(suffix).find())
                    return new Area(city, district);
            }
            if (suffix.isEmpty()) {
                // Also support DISTRICT/CITY without guessing a district from street text.
                String prefix = text.substring(0, match[0]).stripTrailing();
                for (String district : provinces.get(city)) {
                    if (Pattern.compile("(?:^|[^a-z])" + Pattern.quote(normalize(district)) + "\\s*/\\s*$").matcher(prefix).find())
                        return new Area(city, district);
                }
                return new Area(city, "");
            }
            if (text.substring(match[1]).startsWith("/") || suffix.matches("[0-9]+")) return new Area(city, "");
        }
        return new Area("", "");
    }

    public Set<Long> ids(String city, String district) {
        if (city == null || city.isBlank()) {
            if (district != null && !district.isBlank()) throw new IllegalArgumentException("Ilce icin il seciniz");
            return null;
        }
        String canonical = names.get(normalize(city));
        if (canonical == null) throw new IllegalArgumentException("Il bulunamadi");
        String canonicalDistrict = district == null || district.isBlank() ? "" : provinces.get(canonical).stream()
                .filter(value -> normalize(value).equals(normalize(district))).findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Ilce secilen ile ait degil"));
        Set<Long> ids = new HashSet<>();
        index().points.forEach((id, area) -> {
            if (canonical.equals(area.city) && (canonicalDistrict.isEmpty() || canonicalDistrict.equals(area.district))) ids.add(id);
        });
        return ids;
    }

    public Inventory inventory() { return index().inventory; }

    private Index index() {
        Index result = cached;
        if (result != null && result.expiresAt.isAfter(Instant.now())) return result;
        synchronized (this) {
            result = cached;
            if (result != null && result.expiresAt.isAfter(Instant.now())) return result;
            Map<Long, Area> areas = new HashMap<>();
            Map<String, List<MapPinRepository.LocationSummary>> grouped = new HashMap<>();
            var rows = repository.findLocationSummaries();
            for (var row : rows) {
                Area area = resolve(row.getAddress()); areas.put(row.getId(), area);
                grouped.computeIfAbsent(area.city, ignored -> new ArrayList<>()).add(row);
            }
            List<City> cities = new ArrayList<>();
            for (var entry : provinces.entrySet()) {
                var points = grouped.getOrDefault(entry.getKey(), List.of());
                List<District> districts = entry.getValue().stream().map(district -> {
                    var subset = points.stream().filter(p -> district.equals(areas.get(p.getId()).district)).toList();
                    return new District(district, counts(subset), bounds(subset));
                }).toList();
                cities.add(new City(entry.getKey(), counts(points), bounds(points), districts));
            }
            Instant snapshot = rows.stream().map(MapPinRepository.LocationSummary::getSnapshotAt).filter(Objects::nonNull).max(Comparator.naturalOrder()).orElse(null);
            Inventory inventory = new Inventory(rows.size(), counts(rows), grouped.getOrDefault("", List.of()).size(), snapshot, cities);
            cached = result = new Index(Map.copyOf(areas), inventory, Instant.now().plusSeconds(60));
            return result;
        }
    }

    private static Map<String, Long> counts(List<MapPinRepository.LocationSummary> rows) {
        Map<String, Long> counts = new LinkedHashMap<>();
        for (String type : List.of("DIM", "MIN", "KIM", "SDM", "UNKNOWN")) counts.put(type, 0L);
        rows.forEach(p -> counts.merge(counts.containsKey(p.getPointType()) ? p.getPointType() : "UNKNOWN", 1L, Long::sum));
        return Collections.unmodifiableMap(counts);
    }
    private static Bounds bounds(List<MapPinRepository.LocationSummary> rows) {
        var valid = rows.stream().filter(p -> p.getLatitude() != null && p.getLongitude() != null
                && Double.isFinite(p.getLatitude()) && Double.isFinite(p.getLongitude())
                && Math.abs(p.getLatitude()) <= 90 && Math.abs(p.getLongitude()) <= 180).toList();
        if (valid.isEmpty()) return null;
        return new Bounds(valid.stream().mapToDouble(MapPinRepository.LocationSummary::getLatitude).min().orElseThrow(),
                valid.stream().mapToDouble(MapPinRepository.LocationSummary::getLatitude).max().orElseThrow(),
                valid.stream().mapToDouble(MapPinRepository.LocationSummary::getLongitude).min().orElseThrow(),
                valid.stream().mapToDouble(MapPinRepository.LocationSummary::getLongitude).max().orElseThrow());
    }
    public record Area(String city, String district) {}
    public record Bounds(double south, double north, double west, double east) {}
    public record District(String name, Map<String, Long> counts, Bounds bounds) {}
    public record City(String name, Map<String, Long> counts, Bounds bounds, List<District> districts) {}
    public record Inventory(int total, Map<String, Long> counts, int unresolved, Instant snapshotAt, List<City> cities) {}
    private record Index(Map<Long, Area> points, Inventory inventory, Instant expiresAt) {}
}
