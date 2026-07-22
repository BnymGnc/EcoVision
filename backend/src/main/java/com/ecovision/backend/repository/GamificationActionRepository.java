package com.ecovision.backend.repository;

import com.ecovision.backend.model.GamificationAction;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GamificationActionRepository extends JpaRepository<GamificationAction, Long> {
    boolean existsByUserIdAndActionKey(Long userId, String actionKey);

    List<GamificationAction> findByUserIdOrderByCreatedAtAsc(Long userId);
}
