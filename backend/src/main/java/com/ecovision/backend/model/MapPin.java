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
@Table(name = "map_pins")
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

    @Column(length = 30)
    private String workingHours;

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

    public String getWorkingHours() {
        return workingHours;
    }

    public void setWorkingHours(String workingHours) {
        this.workingHours = workingHours;
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
        if (material == null || binStates == null || binStates.isEmpty()) {
            return false;
        }
        return Boolean.TRUE.equals(binStates.get(normalizeMaterial(material)));
    }

    public Set<String> currentlyAcceptedMaterials() {
        if (binStates == null || binStates.isEmpty()) {
            return Set.of();
        }
        return binStates.entrySet().stream()
                .filter(entry -> Boolean.TRUE.equals(entry.getValue()))
                .map(Map.Entry::getKey)
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
