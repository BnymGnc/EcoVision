package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "social_reports")
public class SocialReport {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reporter_id", nullable = false)
    private AppUser reporter;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reported_user_id")
    private AppUser reportedUser;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reported_event_id")
    private Event reportedEvent;

    @Column(nullable = false, length = 80)
    private String reason;

    @Column(length = 1000)
    private String details;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReportStatus status = ReportStatus.OPEN;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() { createdAt = Instant.now(); }

    public Long getId() { return id; }
    public AppUser getReporter() { return reporter; }
    public void setReporter(AppUser reporter) { this.reporter = reporter; }
    public AppUser getReportedUser() { return reportedUser; }
    public void setReportedUser(AppUser reportedUser) { this.reportedUser = reportedUser; }
    public Event getReportedEvent() { return reportedEvent; }
    public void setReportedEvent(Event reportedEvent) { this.reportedEvent = reportedEvent; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }
    public ReportStatus getStatus() { return status; }
    public void setStatus(ReportStatus status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
}
