package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "user_blocks",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_user_block",
                columnNames = {"blocker_id", "blocked_user_id"}
        )
)
public class UserBlock {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "blocker_id", nullable = false)
    private AppUser blocker;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "blocked_user_id", nullable = false)
    private AppUser blockedUser;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() { createdAt = Instant.now(); }

    public AppUser getBlocker() { return blocker; }
    public void setBlocker(AppUser blocker) { this.blocker = blocker; }
    public AppUser getBlockedUser() { return blockedUser; }
    public void setBlockedUser(AppUser blockedUser) { this.blockedUser = blockedUser; }
}
