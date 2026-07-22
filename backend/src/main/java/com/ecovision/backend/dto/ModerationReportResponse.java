package com.ecovision.backend.dto;

import com.ecovision.backend.model.SocialReport;
import java.time.Instant;

public record ModerationReportResponse(
        Long id, Long reporterId, String reporterName,
        Long reportedUserId, String reportedUserName,
        Long groupId, String groupTitle,
        String reason, String details, String status, Instant createdAt
) {
    public static ModerationReportResponse from(SocialReport report) {
        return new ModerationReportResponse(
                report.getId(), report.getReporter().getId(), fullName(report.getReporter()),
                report.getReportedUser() == null ? null : report.getReportedUser().getId(),
                report.getReportedUser() == null ? null : fullName(report.getReportedUser()),
                report.getReportedEvent() == null ? null : report.getReportedEvent().getId(),
                report.getReportedEvent() == null ? null : report.getReportedEvent().getTitle(),
                report.getReason(), report.getDetails(), report.getStatus().name(), report.getCreatedAt()
        );
    }

    private static String fullName(com.ecovision.backend.model.AppUser user) {
        return (user.getName() + " " + user.getSurname()).trim();
    }
}
