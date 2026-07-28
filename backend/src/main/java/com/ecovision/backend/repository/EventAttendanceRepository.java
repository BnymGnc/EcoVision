package com.ecovision.backend.repository;

import com.ecovision.backend.model.AttendanceStatus;
import com.ecovision.backend.model.EventAttendance;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventAttendanceRepository extends JpaRepository<EventAttendance, Long> {
    Optional<EventAttendance> findByEventIdAndUserId(Long eventId, Long userId);

    long countByEventIdAndStatus(Long eventId, AttendanceStatus status);

    @EntityGraph(attributePaths = "user")
    List<EventAttendance> findByEventIdAndStatusOrderByRespondedAtAsc(
            Long eventId,
            AttendanceStatus status
    );

    void deleteByEventId(Long eventId);

    void deleteByEventIdAndUserId(Long eventId, Long userId);
}
