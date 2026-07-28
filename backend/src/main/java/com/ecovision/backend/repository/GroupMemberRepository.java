package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupMember;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupMemberRepository extends JpaRepository<GroupMember, Long> {
    boolean existsByGroupIdAndUserId(Long groupId, Long userId);
    Optional<GroupMember> findByGroupIdAndUserId(Long groupId, Long userId);

    @EntityGraph(attributePaths = "user")
    List<GroupMember> findByGroupIdOrderByJoinedAtAsc(Long groupId);

    @Override
    @EntityGraph(attributePaths = {"group", "user"})
    List<GroupMember> findAll();

    long countByGroupId(Long groupId);
    void deleteByGroupId(Long groupId);
}
