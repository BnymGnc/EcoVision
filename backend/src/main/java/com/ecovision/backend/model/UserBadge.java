package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "user_badges",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_user_badge",
                columnNames = {"user_id", "badge_type"}
        )
)
public class UserBadge {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Enumerated(EnumType.STRING)
    @Column(name = "badge_type", nullable = false)
    private BadgeType badgeType;

    @Column(nullable = false, updatable = false)
    private Instant awardedAt;

    @PrePersist
    void prePersist() { awardedAt = Instant.now(); }

    public Long getId() { return id; }
    public AppUser getUser() { return user; }
    public void setUser(AppUser user) { this.user = user; }
    public BadgeType getBadgeType() { return badgeType; }
    public void setBadgeType(BadgeType badgeType) { this.badgeType = badgeType; }
    public Instant getAwardedAt() { return awardedAt; }
}
