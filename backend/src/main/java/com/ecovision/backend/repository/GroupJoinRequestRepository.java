package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupJoinRequest;
import com.ecovision.backend.model.GroupJoinRequestStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupJoinRequestRepository extends JpaRepository<GroupJoinRequest, Long> {
    Optional<GroupJoinRequest> findByGroupIdAndRequesterId(Long groupId, Long requesterId);

    @EntityGraph(attributePaths = {"group", "requester"})
    List<GroupJoinRequest> findByGroupIdAndStatusOrderByRequestedAtAsc(
            Long groupId,
            GroupJoinRequestStatus status
    );

    void deleteByGroupId(Long groupId);
}
