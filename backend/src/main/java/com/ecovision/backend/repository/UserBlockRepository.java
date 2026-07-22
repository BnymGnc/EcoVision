package com.ecovision.backend.repository;

import com.ecovision.backend.model.UserBlock;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserBlockRepository extends JpaRepository<UserBlock, Long> {
    boolean existsByBlockerIdAndBlockedUserId(Long blockerId, Long blockedUserId);
    void deleteByBlockerIdAndBlockedUserId(Long blockerId, Long blockedUserId);
}
