package com.ecovision.backend.repository;

import com.ecovision.backend.model.AppNotification;
import com.ecovision.backend.model.NotificationType;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AppNotificationRepository extends JpaRepository<AppNotification, Long> {
    List<AppNotification> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    long countByUserIdAndReadFalse(Long userId);
    boolean existsByUserIdAndTypeAndCreatedAtAfter(Long userId, NotificationType type, Instant after);

    @Modifying
    @Query("update AppNotification notification set notification.read = true where notification.user.id = :userId and notification.read = false")
    int markAllRead(@Param("userId") Long userId);
}
