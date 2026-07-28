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
        name = "group_event_attendance",
        uniqueConstraints = @UniqueConstraint(columnNames = {"group_event_id", "user_id"})
)
public class GroupEventAttendance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "group_event_id", nullable = false)
    private GroupEvent event;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AttendanceStatus status;

    @Column(nullable = false)
    private Instant respondedAt;

    @PrePersist
    void prePersist() {
        if (respondedAt == null) {
            respondedAt = Instant.now();
        }
    }

    public Long getId() { return id; }
    public GroupEvent getEvent() { return event; }
    public void setEvent(GroupEvent event) { this.event = event; }
    public AppUser getUser() { return user; }
    public void setUser(AppUser user) { this.user = user; }
    public AttendanceStatus getStatus() { return status; }
    public void setStatus(AttendanceStatus status) {
        this.status = status;
        this.respondedAt = Instant.now();
    }
    public Instant getRespondedAt() { return respondedAt; }
}
