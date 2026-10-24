package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "waste_actions", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "action_key"}))
public class WasteAction {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(name = "action_key", nullable = false, length = 80) private String actionKey;
    @Column(nullable = false, length = 30) private String material;
    @Column(nullable = false) private double massKg;
    @Column(nullable = false, length = 20) private String baseline;
    @Column(nullable = false, length = 20) private String selected;
    private Double estimatedDifferenceKg;
    @Column(nullable = false, length = 30) private String evidence = "USER_DECLARED";
    @Column(nullable = false, length = 50) private String factorVersion;
    @Column(nullable = false) private Instant createdAt;
    public WasteAction() {}
    public WasteAction(AppUser user, String key, String material, double massKg, String baseline,
                       String selected, Double difference, String version) {
        this.user = user; actionKey = key; this.material = material; this.massKg = massKg;
        this.baseline = baseline; this.selected = selected; estimatedDifferenceKg = difference;
        factorVersion = version; createdAt = Instant.now();
    }
    public Long getId() { return id; }
    public AppUser getUser() { return user; }
    public Double getEstimatedDifferenceKg() { return estimatedDifferenceKg; }
    public String getMaterial() { return material; }
    public double getMassKg() { return massKg; }
    public String getBaseline() { return baseline; }
    public String getSelected() { return selected; }
    public String getEvidence() { return evidence; }
    public String getFactorVersion() { return factorVersion; }
    public Instant getCreatedAt() { return createdAt; }
    public void reviseMass(double value, Double difference, String version) {
        massKg = value; estimatedDifferenceKg = difference; factorVersion = version;
    }
}
