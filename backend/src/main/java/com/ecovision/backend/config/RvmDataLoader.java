package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinBin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import jakarta.persistence.EntityManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Configuration(proxyBeanMethods = false)
public class RvmDataLoader {
    public static final String DATA_PATH = "data/data/doa_points_raw.json";
    private static final String MANIFEST_PATH = "data/data/manifest.json";
    private static final Logger LOG = LoggerFactory.getLogger(RvmDataLoader.class);

    @Bean
    @Order(3)
    CommandLineRunner seedRvmMachineCatalog(
            AppUserRepository users, MapPinRepository pins, ObjectMapper mapper,
            @Value("${rvm.import.dry-run:false}") boolean dryRun,
            JdbcTemplate jdbc, PlatformTransactionManager transactions, EntityManager entityManager
    ) {
        return args -> {
            Catalog catalog = loadCatalog(mapper);
            // A transaction lock also works through Neon's transaction pooler.
            // Clearing each flushed batch bounds JPA's persistence context.
            new TransactionTemplate(transactions).executeWithoutResult(status -> {
                jdbc.execute("select pg_advisory_xact_lock(6818462026)");
                ImportReport preview = importCatalog(catalog, users, pins, true);
                LOG.info("DOA import preview: {}", preview);
                if (!dryRun) LOG.info("DOA import result: {}", importCatalog(catalog, users, pins, false, () -> {
                    entityManager.flush(); entityManager.clear();
                }));
            });
        };
    }

    public static Catalog loadCatalog(ObjectMapper mapper) throws Exception {
        byte[] bytes;
        try (InputStream input = new ClassPathResource(DATA_PATH).getInputStream()) {
            bytes = input.readAllBytes();
        }
        JsonNode manifest;
        try (InputStream input = new ClassPathResource(MANIFEST_PATH).getInputStream()) {
            manifest = mapper.readTree(input);
        }
        String hash = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(bytes));
        Instant snapshot = Instant.parse(manifest.path("fetched_at_utc").asText());
        Catalog parsed = parse(mapper.readTree(bytes), mapper, hash, snapshot,
                manifest.path("source_url").asText());
        int expected = manifest.path("unique_points").asInt(-1);
        if (parsed.sourceCount() != expected) {
            throw new IllegalStateException("DOA manifest/source count mismatch");
        }
        return parsed;
    }

    public static List<RvmSeed> loadAndValidate(ObjectMapper mapper) throws Exception {
        return loadCatalog(mapper).points();
    }

    /** Adapters deliberately ignore clusterDataList: clusters are not locations. */
    public static Catalog parse(JsonNode root, ObjectMapper mapper, String hash,
                                Instant snapshot, String sourceUrl) throws Exception {
        JsonNode records = root.isArray() ? root : root.path("rvmList");
        if (!records.isArray() && root.path("data").isObject()) {
            records = root.path("data").path("rvmList");
        }
        if (!records.isArray()) throw new IllegalArgumentException("DOA records must be an array or rvmList");
        List<RvmSeed> points = new ArrayList<>();
        List<String> quarantine = new ArrayList<>();
        Set<String> identities = new HashSet<>();
        for (JsonNode node : records) {
            boolean raw = node.has("definition");
            boolean simplified = node.has("point_type");
            String externalId = text(node, "id");
            String name = raw ? text(node.path("definition"), "name") : text(node, "name");
            String address = text(node, "address");
            double lat = node.path("latitude").asDouble(Double.NaN);
            double lng = node.path("longitude").asDouble(Double.NaN);
            String identity = externalId == null ? legacyIdentity(name, address, lat, lng) : externalId;
            if (name == null || name.isBlank() || !Double.isFinite(lat)
                    || !Double.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180
                    || !identities.add(identity)) {
                quarantine.add(externalId == null ? "invalid-legacy-record" : externalId);
                continue;
            }
            String type = raw ? text(node.path("depositPointType"), "name")
                    : simplified ? text(node, "point_type") : "DIM";
            type = type == null ? "UNKNOWN" : type.toUpperCase(Locale.ROOT);
            if (!Set.of("DIM", "KIM", "MIN", "SDM").contains(type)) type = "UNKNOWN";
            JsonNode binsNode = node.path("binList");
            List<RvmBinSeed> bins = new ArrayList<>();
            List<String> flags = new ArrayList<>();
            if (binsNode.isArray()) for (JsonNode bin : binsNode) {
                String code = text(bin, "contentType");
                if (code == null) code = text(bin, "type");
                if (code == null) { flags.add("BIN_MATERIAL_UNKNOWN"); continue; }
                Integer level = bin.hasNonNull("level") ? bin.get("level").asInt() : null;
                Boolean state = bin.hasNonNull("state") ? bin.get("state").asBoolean() : null;
                if (level != null && (level < 0 || level > 100)) flags.add("BIN_LEVEL_OUT_OF_RANGE");
                bins.add(new RvmBinSeed(code, level, state));
            }
            Set<String> codes = new LinkedHashSet<>();
            JsonNode materialNode = raw ? node.path("contentType") : node.path("accepted_materials");
            if (materialNode.isArray()) materialNode.forEach(value -> codes.add(value.asText()));
            // can -> aluminum is provider-specific and requires corroborating bin data.
            Set<String> accepted = new LinkedHashSet<>();
            for (String code : codes) {
                if (!code.equalsIgnoreCase("can")) accepted.add(normalizeMaterial(code));
                else if (bins.stream().anyMatch(b -> b.contentType().equals("aluminum"))) accepted.add("aluminum");
                else flags.add("CAN_MATERIAL_UNVERIFIED");
            }
            bins.forEach(bin -> accepted.add(normalizeMaterial(bin.contentType())));
            if (bins.isEmpty()) flags.add("BIN_AVAILABILITY_UNKNOWN");
            JsonNode schedule = raw ? node.path("weeklySchedule") : node.path("weekly_schedule");
            if (!schedule.isArray()) { schedule = mapper.createArrayNode(); flags.add("SCHEDULE_UNKNOWN"); }
            flags.add("TELEMETRY_TIMESTAMP_UNKNOWN");
            if (!raw && !simplified) flags.add("LEGACY_PARTIAL_SOURCE");
            points.add(new RvmSeed(externalId, name, lat, lng, address == null ? "" : address,
                    List.copyOf(bins), type, Set.copyOf(accepted), mapper.writeValueAsString(codes),
                    mapper.writeValueAsString(schedule), nullableBoolean(node.get("active")),
                    nullableInteger(node.get("status")), nullableInteger(node.get("machineStatus")),
                    mapper.writeValueAsString(binsNode.isArray() ? binsNode : mapper.createArrayNode()),
                    mapper.writeValueAsString(flags)));
        }
        return new Catalog(List.copyOf(points), records.size(), List.copyOf(quarantine), hash,
                snapshot, sourceUrl);
    }

    public static ImportReport importCatalog(Catalog catalog, AppUserRepository users,
                                             MapPinRepository pins, boolean dryRun) {
        return importCatalog(catalog, users, pins, dryRun, () -> {});
    }

    private static ImportReport importCatalog(Catalog catalog, AppUserRepository users,
                                             MapPinRepository pins, boolean dryRun, Runnable afterBatch) {
        if (pins.countByProviderAndDatasetHash("DOA", catalog.hash()) == catalog.points().size()) {
            return new ImportReport(catalog.sourceCount(), 0, 0, catalog.points().size(),
                    catalog.quarantineIds().size(), dryRun);
        }
        Map<String, MapPinRepository.CatalogIdentity> byExternal = new HashMap<>();
        Map<String, List<MapPinRepository.CatalogIdentity>> legacy = new HashMap<>();
        for (var existing : pins.findCatalogIdentities()) {
            if ("DOA".equals(existing.getProvider()) && existing.getExternalId() != null)
                byExternal.put(existing.getExternalId(), existing);
            else if (existing.getExternalId() == null)
                legacy.computeIfAbsent(legacyIdentity(existing.getTitle(), existing.getAddress(),
                        existing.getLatitude(), existing.getLongitude()), key -> new ArrayList<>()).add(existing);
        }
        AppUser owner = dryRun ? null : users.findByEmail("admin@ecovision.com")
                .orElseThrow(() -> new IllegalStateException("DOA catalog owner not found"));
        int inserted = 0, updated = 0, unchanged = 0;
        List<MapPin> batch = new ArrayList<>();
        for (RvmSeed seed : catalog.points()) {
            var existing = byExternal.get(seed.externalId());
            if (existing == null) {
                var matches = legacy.getOrDefault(legacyIdentity(seed.name(), seed.address(),
                        seed.latitude(), seed.longitude()), List.of());
                if (matches.size() == 1) existing = matches.get(0);
            }
            if (existing != null && (catalog.hash().equals(existing.getDatasetHash())
                    || existing.getSnapshotAt() != null && catalog.snapshotAt().isBefore(existing.getSnapshotAt()))) {
                unchanged++;
                continue;
            }
            if (existing == null) inserted++; else updated++;
            if (dryRun) continue;
            MapPin pin = existing == null ? new MapPin() : pins.findById(existing.getId()).orElseThrow();
            apply(seed, pin, owner);
            pin.setDatasetHash(catalog.hash());
            pin.setDatasetVersion(catalog.snapshotAt().toString());
            pin.setSnapshotAt(catalog.snapshotAt());
            pin.setSourceUrl(catalog.sourceUrl());
            pin.setImportedAt(Instant.now());
            batch.add(pin);
            if (batch.size() == 100) { pins.saveAll(batch); pins.flush(); afterBatch.run(); batch.clear(); }
        }
        if (!dryRun && !batch.isEmpty()) { pins.saveAll(batch); pins.flush(); afterBatch.run(); }
        return new ImportReport(catalog.sourceCount(), inserted, updated, unchanged,
                catalog.quarantineIds().size(), dryRun);
    }

    public static void apply(RvmSeed seed, MapPin pin, AppUser owner) {
        pin.setTitle(seed.name()); pin.setAddress(seed.address());
        pin.setLatitude(seed.latitude()); pin.setLongitude(seed.longitude());
        pin.setProvider("DOA"); pin.setExternalId(seed.externalId()); pin.setPointType(seed.pointType());
        pin.setAcceptedMaterials(new LinkedHashSet<>(seed.acceptedMaterials()));
        Map<String, Boolean> states = new LinkedHashMap<>();
        List<MapPinBin> bins = new ArrayList<>();
        for (var bin : seed.binList()) {
            if (bin.state() != null) states.put(normalizeMaterial(bin.contentType()), bin.state());
            bins.add(new MapPinBin(bin.contentType(), bin.level() == null ? -1 : bin.level(), Boolean.TRUE.equals(bin.state())));
        }
        pin.setBinStates(states); pin.setBinList(bins);
        pin.setSourceMaterialCodesJson(seed.sourceMaterialCodesJson()); pin.setRawBinsJson(seed.rawBinsJson());
        pin.setWeeklyScheduleJson(seed.weeklyScheduleJson()); pin.setTimezone("Europe/Istanbul");
        pin.setSourceActiveRaw(seed.sourceActiveRaw()); pin.setSourceStatusRaw(seed.sourceStatusRaw());
        pin.setSourceMachineStatusRaw(seed.sourceMachineStatusRaw()); pin.setTelemetryObservedAt(null);
        pin.setDataQualityFlags(seed.dataQualityFlags());
        pin.setActive(true); pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
        if (pin.getCreatedBy() == null) pin.setCreatedBy(owner);
    }

    public static String normalizeMaterial(String value) {
        return switch (value.trim().toLowerCase(Locale.ROOT)) {
            case "cam" -> "glass";
            case "aluminium", "alüminyum", "aluminyum" -> "aluminum";
            default -> value.trim().toLowerCase(Locale.ROOT);
        };
    }
    public static String normalizeName(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.forLanguageTag("tr"));
    }
    public static String coordinateKey(double lat, double lng) {
        return String.format(Locale.ROOT, "%.7f|%.7f", lat, lng);
    }
    private static String legacyIdentity(String name, String address, double lat, double lng) {
        return normalizeName(name) + "|" + normalizeName(address) + "|" + coordinateKey(lat, lng);
    }
    private static String text(JsonNode node, String key) { return node.hasNonNull(key) ? node.get(key).asText() : null; }
    private static Boolean nullableBoolean(JsonNode node) { return node == null || node.isNull() ? null : node.asBoolean(); }
    private static Integer nullableInteger(JsonNode node) { return node == null || node.isNull() ? null : node.asInt(); }
    public record RvmSeed(String externalId, String name, double latitude, double longitude, String address,
                          List<RvmBinSeed> binList, String pointType, Set<String> acceptedMaterials,
                          String sourceMaterialCodesJson, String weeklyScheduleJson, Boolean sourceActiveRaw,
                          Integer sourceStatusRaw, Integer sourceMachineStatusRaw, String rawBinsJson,
                          String dataQualityFlags) {}
    public record RvmBinSeed(String contentType, Integer level, Boolean state) {}
    public record Catalog(List<RvmSeed> points, int sourceCount, List<String> quarantineIds,
                          String hash, Instant snapshotAt, String sourceUrl) {}
    public record ImportReport(int source, int inserted, int updated, int unchanged, int invalid, boolean dryRun) {}
}
