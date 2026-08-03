package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupEvent;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface GroupEventRepository extends JpaRepository<GroupEvent, Long> {
    @EntityGraph(attributePaths = {"group", "creator"})
    List<GroupEvent> findByGroupIdOrderByEventDateDesc(Long groupId);

    @EntityGraph(attributePaths = {"group", "creator"})
    Optional<GroupEvent> findByIdAndGroupId(Long id, Long groupId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select event from GroupEvent event
            join fetch event.group
            join fetch event.creator
            where event.id = :eventId and event.group.id = :groupId
            """)
    Optional<GroupEvent> findByIdForUpdate(
            @Param("groupId") Long groupId,
            @Param("eventId") Long eventId
    );

    void deleteByGroupId(Long groupId);
}
