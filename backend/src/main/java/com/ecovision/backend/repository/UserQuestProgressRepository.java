package com.ecovision.backend.repository;

import com.ecovision.backend.model.UserQuestProgress;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserQuestProgressRepository
        extends JpaRepository<UserQuestProgress, Long> {
    @EntityGraph(attributePaths = "quest")
    Optional<UserQuestProgress>
    findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
            Long userId,
            Long questId
    );

    @EntityGraph(attributePaths = "quest")
    List<UserQuestProgress> findByUserIdAndArchivedAtIsNullOrderByAssignedAtDesc(
            Long userId
    );

    boolean existsByUserIdAndQuestIdAndArchivedAtIsNullAndExpiresAtAfter(
            Long userId,
            Long questId,
            Instant now
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select progress from UserQuestProgress progress
            join fetch progress.quest
            where progress.id = :id
            """)
    Optional<UserQuestProgress> findByIdForUpdate(@Param("id") Long id);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update UserQuestProgress progress
            set progress.archivedAt = :now
            where progress.archivedAt is null
              and progress.completed = false
              and progress.expiresAt is not null
              and progress.expiresAt <= :now
            """)
    int archiveExpiredUncompleted(@Param("now") Instant now);
}
