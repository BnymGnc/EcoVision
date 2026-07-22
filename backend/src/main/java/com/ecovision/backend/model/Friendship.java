package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "friendships",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_friendship_pair",
                columnNames = {"requester_id", "addressee_id"}
        )
)
public class Friendship {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_id", nullable = false)
    private AppUser requester;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "addressee_id", nullable = false)
    private AppUser addressee;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private FriendshipStatus status = FriendshipStatus.PENDING;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    private Instant respondedAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public AppUser getRequester() { return requester; }
    public void setRequester(AppUser requester) { this.requester = requester; }
    public AppUser getAddressee() { return addressee; }
    public void setAddressee(AppUser addressee) { this.addressee = addressee; }
    public FriendshipStatus getStatus() { return status; }
    public void setStatus(FriendshipStatus status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getRespondedAt() { return respondedAt; }
    public void setRespondedAt(Instant respondedAt) { this.respondedAt = respondedAt; }
}
