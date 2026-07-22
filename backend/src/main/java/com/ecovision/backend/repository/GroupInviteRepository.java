package com.ecovision.backend.repository;

import com.ecovision.backend.model.GroupInvite;
import com.ecovision.backend.model.InviteStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupInviteRepository extends JpaRepository<GroupInvite, Long> {
    boolean existsByEventIdAndInviteeIdAndStatus(Long eventId, Long inviteeId, InviteStatus status);

    @EntityGraph(attributePaths = {"event", "event.creator", "inviter", "invitee"})
    List<GroupInvite> findByInviteeIdAndStatusOrderByCreatedAtDesc(
            Long inviteeId,
            InviteStatus status
    );

    @EntityGraph(attributePaths = {"event", "event.creator", "inviter", "invitee"})
    Optional<GroupInvite> findWithRelationsById(Long id);

    void deleteByEventId(Long eventId);
}
