package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupEvent;
import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupEventRepository extends JpaRepository<GroupEvent, Long> {
    @EntityGraph(attributePaths = {"group", "creator"})
    List<GroupEvent> findByGroupIdAndEventDateGreaterThanEqualOrderByEventDateAsc(
            Long groupId,
            Instant from
    );

    void deleteByGroupId(Long groupId);
}
