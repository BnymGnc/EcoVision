package com.ecovision.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "quests")
public class Quest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 80)
    private String code;

    @Column(nullable = false, length = 140)
    private String title;

    @Column(nullable = false, length = 1000)
    private String description;

    @Column(nullable = false)
    private Integer rewardPoints;

    @Column(nullable = false)
    private Integer targetAmount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private QuestCategory questCategory;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private QuestTriggerType triggerType;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private QuestDomain domain = QuestDomain.ECO_IMPACT;

    @Column(nullable = false, columnDefinition = "text")
    private String criteriaJson = "{}";

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
        if (criteriaJson == null || criteriaJson.isBlank()) {
            criteriaJson = "{}";
        }
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Integer getRewardPoints() {
        return rewardPoints;
    }

    public void setRewardPoints(Integer rewardPoints) {
        this.rewardPoints = rewardPoints;
    }

    public Integer getTargetAmount() {
        return targetAmount;
    }

    public void setTargetAmount(Integer targetAmount) {
        this.targetAmount = targetAmount;
    }

    public QuestCategory getQuestCategory() {
        return questCategory;
    }

    public void setQuestCategory(QuestCategory questCategory) {
        this.questCategory = questCategory;
    }

    public QuestTriggerType getTriggerType() {
        return triggerType;
    }

    public void setTriggerType(QuestTriggerType triggerType) {
        this.triggerType = triggerType;
    }

    public QuestDomain getDomain() {
        return domain;
    }

    public void setDomain(QuestDomain domain) {
        this.domain = domain;
    }

    public String getCriteriaJson() {
        return criteriaJson;
    }

    public void setCriteriaJson(String criteriaJson) {
        this.criteriaJson = criteriaJson;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
