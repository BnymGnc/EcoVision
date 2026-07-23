package com.ecovision.backend.repository;

import com.ecovision.backend.model.EventMember;
import java.util.Optional;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventMemberRepository extends JpaRepository<EventMember, Long> {
    boolean existsByEventIdAndUserId(Long eventId, Long userId);

    Optional<EventMember> findByEventIdAndUserId(Long eventId, Long userId);

    @EntityGraph(attributePaths = "user")
    List<EventMember> findByEventIdOrderByJoinedAtAsc(Long eventId);

    @EntityGraph(attributePaths = {"event", "user"})
    List<EventMember> findByUserId(Long userId);

    long countByEventId(Long eventId);

    void deleteByEventId(Long eventId);
}
