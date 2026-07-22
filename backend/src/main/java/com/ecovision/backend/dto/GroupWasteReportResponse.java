package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupWasteReport;
import java.time.Instant;

public record GroupWasteReportResponse(
        Long id,
        Long eventId,
        Long reporterId,
        String reporterName,
        String materialType,
        Integer itemCount,
        Instant reportedAt
) {
    public static GroupWasteReportResponse from(GroupWasteReport report) {
        return new GroupWasteReportResponse(
                report.getId(), report.getEvent().getId(), report.getReporter().getId(),
                report.getReporter().getName() + " " + report.getReporter().getSurname(),
                report.getMaterialType(), report.getItemCount(), report.getReportedAt()
        );
    }
}
