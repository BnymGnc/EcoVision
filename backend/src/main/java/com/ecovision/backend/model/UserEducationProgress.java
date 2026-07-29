package com.ecovision.backend.model;

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
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;

@Entity
@Table(
        name = "user_education_progress",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_education_progress_user_category",
                columnNames = {"user_id", "category_id"}
        )
)
public class UserEducationProgress {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "category_id", nullable = false, length = 40)
    private String categoryId;

    @Column(nullable = false, updatable = false)
    private Instant completedAt;

    @PrePersist
    void prePersist() {
        if (completedAt == null) {
            completedAt = Instant.now();
        }
    }

    public Long getId() {
        return id;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getCategoryId() {
        return categoryId;
    }

    public void setCategoryId(String categoryId) {
        this.categoryId = categoryId;
    }

    public Instant getCompletedAt() {
        return completedAt;
    }
}
