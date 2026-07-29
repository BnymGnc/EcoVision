package com.ecovision.backend.repository;

import com.ecovision.backend.model.CommunityGroup;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CommunityGroupRepository extends JpaRepository<CommunityGroup, Long> {
    @Override
    @EntityGraph(attributePaths = "creator")
    List<CommunityGroup> findAll();

    Optional<CommunityGroup> findByLegacyEventId(Long legacyEventId);
    Optional<CommunityGroup> findByInviteCode(String inviteCode);
}
