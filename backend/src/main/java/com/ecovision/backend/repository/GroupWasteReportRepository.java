package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupWasteReport;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupWasteReportRepository extends JpaRepository<GroupWasteReport, Long> {
    @EntityGraph(attributePaths = {"event", "reporter"})
    List<GroupWasteReport> findByEventIdOrderByReportedAtDesc(Long eventId);

    void deleteByEventId(Long eventId);
}
