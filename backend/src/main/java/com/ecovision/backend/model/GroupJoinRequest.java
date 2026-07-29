package com.ecovision.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
        name = "group_join_requests",
        uniqueConstraints = @UniqueConstraint(columnNames = {"group_id", "requester_id"})
)
public class GroupJoinRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "group_id", nullable = false)
    private CommunityGroup group;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_id", nullable = false)
    private AppUser requester;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private GroupJoinRequestStatus status = GroupJoinRequestStatus.PENDING;

    @Column(nullable = false, updatable = false)
    private Instant requestedAt;

    private Instant respondedAt;

    @PrePersist
    void prePersist() {
        if (requestedAt == null) {
            requestedAt = Instant.now();
        }
    }

    public Long getId() { return id; }
    public CommunityGroup getGroup() { return group; }
    public void setGroup(CommunityGroup group) { this.group = group; }
    public AppUser getRequester() { return requester; }
    public void setRequester(AppUser requester) { this.requester = requester; }
    public GroupJoinRequestStatus getStatus() { return status; }
    public void setStatus(GroupJoinRequestStatus status) { this.status = status; }
    public Instant getRequestedAt() { return requestedAt; }
    public Instant getRespondedAt() { return respondedAt; }
    public void setRespondedAt(Instant respondedAt) { this.respondedAt = respondedAt; }
}
