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
@Table(name = "scan_history")
public class ScanHistory {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(nullable = false)
    private String materialType;

    @Column(name = "is_recyclable", nullable = false)
    private Boolean isRecyclable;

    private String decayYears;

    private String recycledInto;

    private Integer pointsAwarded;
    @Column(unique = true)
    private java.util.UUID analysisId;
    @Column(length = 64)
    private String imageHash;
    private java.time.LocalDate rewardDate;
    @Column(length = 30)
    private String rewardStatus;

    public java.util.UUID getAnalysisId() { return analysisId; }
    public void setAnalysisId(java.util.UUID value) { analysisId=value; }
    public String getImageHash() { return imageHash; }
    public void setImageHash(String value) { imageHash=value; }
    public java.time.LocalDate getRewardDate() { return rewardDate; }
    public void setRewardDate(java.time.LocalDate value) { rewardDate=value; }
    public String getRewardStatus() { return rewardStatus; }
    public void setRewardStatus(String value) { rewardStatus=value; }

    @Column(nullable = false)
    private Instant scannedAt;

    @PrePersist
    void prePersist() {
        if (scannedAt == null) {
            scannedAt = Instant.now();
        }
    }

    public Long getId() {
        return id;
    }

    @JsonIgnore
    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getMaterialType() {
        return materialType;
    }

    public void setMaterialType(String materialType) {
        this.materialType = materialType;
    }

    public Boolean getIsRecyclable() {
        return isRecyclable;
    }

    public void setIsRecyclable(Boolean isRecyclable) {
        this.isRecyclable = isRecyclable;
    }

    public String getDecayYears() {
        return decayYears;
    }

    public void setDecayYears(String decayYears) {
        this.decayYears = decayYears;
    }

    public String getRecycledInto() {
        return recycledInto;
    }

    public void setRecycledInto(String recycledInto) {
        this.recycledInto = recycledInto;
    }

    public Integer getPointsAwarded() {
        return pointsAwarded == null ? 0 : pointsAwarded;
    }

    public void setPointsAwarded(Integer pointsAwarded) {
        this.pointsAwarded = pointsAwarded;
    }

    public Instant getScannedAt() {
        return scannedAt;
    }

    public void setScannedAt(Instant scannedAt) {
        this.scannedAt = scannedAt;
    }
}
