package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "profile_likes",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_profile_like",
                columnNames = {"liker_id", "liked_user_id"}
        )
)
public class ProfileLike {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "liker_id", nullable = false)
    private AppUser liker;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "liked_user_id", nullable = false)
    private AppUser likedUser;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() { createdAt = Instant.now(); }

    public Long getId() { return id; }
    public AppUser getLiker() { return liker; }
    public void setLiker(AppUser liker) { this.liker = liker; }
    public AppUser getLikedUser() { return likedUser; }
    public void setLikedUser(AppUser likedUser) { this.likedUser = likedUser; }
    public Instant getCreatedAt() { return createdAt; }
}
