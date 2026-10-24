package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name = "carbon_assessments")
public class CarbonAssessment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(nullable = false, columnDefinition = "text") private String inputsJson;
    @Column(nullable = false, columnDefinition = "text") private String resultJson;
    @Column(nullable = false) private Instant createdAt;
    protected CarbonAssessment() {}
    public CarbonAssessment(AppUser user, String inputsJson, String resultJson) {
        this.user = user; this.inputsJson = inputsJson; this.resultJson = resultJson; this.createdAt = Instant.now();
    }
    public Long getId() { return id; }
    public String getResultJson() { return resultJson; }
    public Instant getCreatedAt() { return createdAt; }
}
