package com.ecovision.backend.repository;

import com.ecovision.backend.model.SocialReport;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;

public interface SocialReportRepository extends JpaRepository<SocialReport, Long> {
    void deleteByReportedEventId(Long eventId);

    @EntityGraph(attributePaths = {"reporter", "reportedUser", "reportedEvent", "reportedEvent.creator"})
    List<SocialReport> findAllByOrderByCreatedAtDesc();
}
