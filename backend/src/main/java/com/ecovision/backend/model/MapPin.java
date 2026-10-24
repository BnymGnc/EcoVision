package com.ecovision.backend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapKeyColumn;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Entity
@Table(name = "map_pins", uniqueConstraints = @jakarta.persistence.UniqueConstraint(
        name = "uk_map_pins_provider_external_id", columnNames = {"provider", "external_id"}),
        indexes = @jakarta.persistence.Index(name = "idx_map_pins_coordinates", columnList = "latitude,longitude"))
public class MapPin {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    @Column(length = 500)
    private String address;

    @Column(nullable = false, length = 30)
    private String provider = "ECOVISION";

    @Column(name = "external_id", length = 100)
    private String externalId;

    @Column(name = "point_type", nullable = false, length = 20)
    private String pointType = "UNKNOWN";

    @Column(name = "weekly_schedule_json", columnDefinition = "text")
    private String weeklyScheduleJson;

    @Column(nullable = false, length = 50)
    private String timezone = "Europe/Istanbul";

    @Column(name = "source_status_raw")
    private Integer sourceStatusRaw;

    @Column(name = "source_active_raw")
    private Boolean sourceActiveRaw;

    @Column(name = "source_machine_status_raw")
    private Integer sourceMachineStatusRaw;

    @Column(name = "source_url", length = 500)
    private String sourceUrl;

    @Column(name = "dataset_version", length = 100)
    private String datasetVersion;

    @Column(name = "dataset_hash", length = 64)
    private String datasetHash;

    @Column(name = "snapshot_at")
    private Instant snapshotAt;

    @Column(name = "imported_at")
    private Instant importedAt;

    @Column(name = "telemetry_observed_at")
    private Instant telemetryObservedAt;

    @Column(name = "data_quality_flags", columnDefinition = "text")
    private String dataQualityFlags;

    @Column(name = "source_material_codes_json", columnDefinition = "text")
    private String sourceMaterialCodesJson;

    @Column(name = "raw_bins_json", columnDefinition = "text")
    private String rawBinsJson;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "map_pin_materials",
            joinColumns = @JoinColumn(name = "map_pin_id")
    )
    @Column(name = "material", nullable = false, length = 30)
    private Set<String> acceptedMaterials = new LinkedHashSet<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "map_pin_bin_states",
            joinColumns = @JoinColumn(name = "map_pin_id")
    )
    @MapKeyColumn(name = "material_type")
    @Column(name = "accepting", nullable = false)
    private Map<String, Boolean> binStates = new LinkedHashMap<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "map_pin_bins",
            joinColumns = @JoinColumn(name = "map_pin_id")
    )
    @OrderColumn(name = "bin_order")
    private List<MapPinBin> binList = new ArrayList<>();

    @Column(nullable = false)
    private boolean active = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MapPinType type = MapPinType.OFFICIAL_RECYCLING_BIN;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by_id", nullable = false)
    private AppUser createdBy;

    @Column(nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public Long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public MapPinType getType() {
        return type;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getProvider() { return provider; }
    public String getSourceMaterialCodesJson() { return sourceMaterialCodesJson; }
    public void setSourceMaterialCodesJson(String value) { sourceMaterialCodesJson = value; }
    public String getRawBinsJson() { return rawBinsJson; }
    public void setRawBinsJson(String value) { rawBinsJson = value; }
    public void setProvider(String provider) { this.provider = provider; }
    public String getExternalId() { return externalId; }
    public void setExternalId(String externalId) { this.externalId = externalId; }
    public String getPointType() { return pointType; }
    public void setPointType(String pointType) { this.pointType = pointType; }
    public String getWeeklyScheduleJson() { return weeklyScheduleJson; }
    public void setWeeklyScheduleJson(String weeklyScheduleJson) {
        this.weeklyScheduleJson = weeklyScheduleJson;
    }
    public String getTimezone() { return timezone; }
    public void setTimezone(String timezone) { this.timezone = timezone; }
    public Integer getSourceStatusRaw() { return sourceStatusRaw; }
    public void setSourceStatusRaw(Integer sourceStatusRaw) {
        this.sourceStatusRaw = sourceStatusRaw;
    }
    public Boolean getSourceActiveRaw() { return sourceActiveRaw; }
    public void setSourceActiveRaw(Boolean sourceActiveRaw) {
        this.sourceActiveRaw = sourceActiveRaw;
    }
    public Integer getSourceMachineStatusRaw() { return sourceMachineStatusRaw; }
    public void setSourceMachineStatusRaw(Integer sourceMachineStatusRaw) {
        this.sourceMachineStatusRaw = sourceMachineStatusRaw;
    }
    public String getSourceUrl() { return sourceUrl; }
    public void setSourceUrl(String sourceUrl) { this.sourceUrl = sourceUrl; }
    public String getDatasetVersion() { return datasetVersion; }
    public void setDatasetVersion(String datasetVersion) {
        this.datasetVersion = datasetVersion;
    }
    public String getDatasetHash() { return datasetHash; }
    public void setDatasetHash(String datasetHash) { this.datasetHash = datasetHash; }
    public Instant getSnapshotAt() { return snapshotAt; }
    public void setSnapshotAt(Instant snapshotAt) { this.snapshotAt = snapshotAt; }
    public Instant getImportedAt() { return importedAt; }
    public void setImportedAt(Instant importedAt) { this.importedAt = importedAt; }
    public Instant getTelemetryObservedAt() { return telemetryObservedAt; }
    public void setTelemetryObservedAt(Instant telemetryObservedAt) {
        this.telemetryObservedAt = telemetryObservedAt;
    }
    public String getDataQualityFlags() { return dataQualityFlags; }
    public void setDataQualityFlags(String dataQualityFlags) {
        this.dataQualityFlags = dataQualityFlags;
    }

    public Set<String> getAcceptedMaterials() {
        return acceptedMaterials;
    }

    public void setAcceptedMaterials(Set<String> acceptedMaterials) {
        this.acceptedMaterials = acceptedMaterials;
    }

    public Map<String, Boolean> getBinStates() {
        return binStates;
    }

    public void setBinStates(Map<String, Boolean> binStates) {
        this.binStates = binStates == null
                ? new LinkedHashMap<>()
                : new LinkedHashMap<>(binStates);
    }

    public List<MapPinBin> getBinList() {
        return binList;
    }

    public void setBinList(List<MapPinBin> binList) {
        this.binList = binList == null
                ? new ArrayList<>()
                : new ArrayList<>(binList);
    }

    public boolean acceptsMaterial(String material) {
        if (material == null || binList == null || binList.isEmpty()) {
            return false;
        }
        String expected = normalizeMaterial(material);
        return binList.stream().anyMatch(bin ->
                bin.isState()
                        && expected.equals(normalizeMaterial(bin.getContentType()))
        );
    }

    public Set<String> currentlyAcceptedMaterials() {
        if (binList == null || binList.isEmpty()) {
            return Set.of();
        }
        return binList.stream()
                .filter(MapPinBin::isState)
                .map(MapPinBin::getContentType)
                .map(this::normalizeMaterial)
                .collect(java.util.stream.Collectors.toUnmodifiableSet());
    }

    private String normalizeMaterial(String material) {
        String normalized = material.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "plastic", "plastik" -> "pet";
            case "cam" -> "glass";
            case "aluminium", "alüminyum", "aluminyum" -> "aluminum";
            default -> normalized;
        };
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public void setType(MapPinType type) {
        this.type = type;
    }

    @JsonIgnore
    public AppUser getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(AppUser createdBy) {
        this.createdBy = createdBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
