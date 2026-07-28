package com.ecovision.backend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "community_groups")
public class CommunityGroup {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "creator_id", nullable = false)
    private AppUser creator;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, length = 2000)
    private String description;

    @Column(nullable = false, length = 80)
    private String city;

    @Column(nullable = false, length = 80)
    private String district;

    @Column(length = 120)
    private String neighborhood;

    private String coverImageUrl;

    @Column(nullable = false)
    private Integer memberLimit = 20;

    private String joinCodeHash;

    @Column(unique = true)
    private Long legacyEventId;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public Long getId() { return id; }
    public AppUser getCreator() { return creator; }
    public void setCreator(AppUser creator) { this.creator = creator; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getDistrict() { return district; }
    public void setDistrict(String district) { this.district = district; }
    public String getNeighborhood() { return neighborhood; }
    public void setNeighborhood(String neighborhood) { this.neighborhood = neighborhood; }
    public String getCoverImageUrl() { return coverImageUrl; }
    public void setCoverImageUrl(String coverImageUrl) { this.coverImageUrl = coverImageUrl; }
    public Integer getMemberLimit() { return memberLimit == null ? 20 : memberLimit; }
    public void setMemberLimit(Integer memberLimit) { this.memberLimit = memberLimit; }

    @JsonIgnore
    public String getJoinCodeHash() { return joinCodeHash; }
    public void setJoinCodeHash(String joinCodeHash) { this.joinCodeHash = joinCodeHash; }
    public Instant getCreatedAt() { return createdAt; }
    public Long getLegacyEventId() { return legacyEventId; }
    public void setLegacyEventId(Long legacyEventId) { this.legacyEventId = legacyEventId; }
    public boolean isPrivateGroup() {
        return joinCodeHash != null && !joinCodeHash.isBlank();
    }
}
