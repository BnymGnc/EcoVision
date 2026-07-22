package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupMission;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupMissionRepository extends JpaRepository<GroupMission, Long> {
    List<GroupMission> findByEventIdOrderByCreatedAtDesc(Long eventId);

    void deleteByEventId(Long eventId);
}
