package com.ecovision.backend.repository;

import com.ecovision.backend.model.BadgeType;
import com.ecovision.backend.model.UserBadge;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserBadgeRepository extends JpaRepository<UserBadge, Long> {
    boolean existsByUserIdAndBadgeType(Long userId, BadgeType badgeType);

    @EntityGraph(attributePaths = "user")
    List<UserBadge> findByUserIdOrderByAwardedAtAsc(Long userId);
}
