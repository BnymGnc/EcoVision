package com.ecovision.backend.service;

import com.ecovision.backend.repository.ScanHistoryRepository.RecyclingCount;
import java.util.*;

/** Educational recycling scenario, not proof of mass, collection or avoided emissions. */
public final class RecyclingPotential {
    private RecyclingPotential() {}

    public static String materialKey(String value) {
        if (value == null) return null;
        String key = value.trim().toLowerCase(Locale.ROOT);
        // Do not silently treat generic plastic as PET or generic metal as aluminium.
        return switch (key) {
            case "pet", "pet bottle", "pet şişe", "pet şişesi" -> "pet";
            case "glass", "cam", "cam atık" -> "glass";
            case "aluminum", "aluminium", "alüminyum", "alüminyum kutu" -> "aluminum";
            default -> null;
        };
    }

    public static Estimate estimate(List<RecyclingCount> rows) {
        long total = 0, modeled = 0;
        double kg = 0;
        Map<String, Long> counts = new TreeMap<>();
        for (var row : rows) {
            long count = row.getScanCount();
            if (count <= 0) continue;
            total += count;
            String key = materialKey(row.getMaterial());
            if (key != null) counts.merge(key, count, Long::sum);
        }
        List<Part> parts = new ArrayList<>();
        for (var entry : counts.entrySet()) {
            // Product-defined illustrative masses per scan, NOT measured average item weights.
            double mass = switch (entry.getKey()) {
                case "pet" -> 0.025;
                case "glass" -> 0.200;
                case "aluminum" -> 0.015;
                default -> throw new IllegalStateException("Unsupported recycling scenario");
            };
            double perKg = Objects.requireNonNull(CarbonMath.wasteDifference(
                    entry.getKey(), 1, "LANDFILL", "RECYCLING"));
            double difference = entry.getValue() * mass * perKg;
            parts.add(new Part(entry.getKey(), entry.getValue(), mass, perKg, difference));
            modeled += entry.getValue();
            kg += difference;
        }
        return new Estimate(total, modeled, total - modeled, kg, "ILLUSTRATIVE_SCAN_SCENARIO",
                "SCAN-MASS-SCENARIO-v1/" + CarbonMath.VERSION, CarbonMath.WARM_SOURCE, List.copyOf(parts));
    }

    public record Part(String material, long scanCount, double assumedMassKgPerScan,
                       double kgCo2ePerKg, double potentialKgCo2e) {}
    public record Estimate(long recyclableScanCount, long modeledScanCount, long unmodeledScanCount,
                           double potentialKgCo2e, String evidence, String factorVersion,
                           String sourceUrl, List<Part> materials) {}
}
