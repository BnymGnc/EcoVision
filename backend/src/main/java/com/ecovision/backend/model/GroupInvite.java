package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "group_invites",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_group_invite",
                columnNames = {"event_id", "invitee_id"}
        )
)
public class GroupInvite {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "inviter_id", nullable = false)
    private AppUser inviter;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "invitee_id", nullable = false)
    private AppUser invitee;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private InviteStatus status = InviteStatus.PENDING;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    private Instant respondedAt;

    @PrePersist
    void prePersist() { createdAt = Instant.now(); }

    public Long getId() { return id; }
    public Event getEvent() { return event; }
    public void setEvent(Event event) { this.event = event; }
    public AppUser getInviter() { return inviter; }
    public void setInviter(AppUser inviter) { this.inviter = inviter; }
    public AppUser getInvitee() { return invitee; }
    public void setInvitee(AppUser invitee) { this.invitee = invitee; }
    public InviteStatus getStatus() { return status; }
    public void setStatus(InviteStatus status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
    public void setRespondedAt(Instant respondedAt) { this.respondedAt = respondedAt; }
}
