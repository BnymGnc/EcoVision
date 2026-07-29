package com.ecovision.backend.repository;

import com.ecovision.backend.model.ChatReaction;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatReactionRepository extends JpaRepository<ChatReaction, Long> {
    Optional<ChatReaction> findByMessageIdAndUserId(Long messageId, Long userId);

    @EntityGraph(attributePaths = "user")
    List<ChatReaction> findByMessageId(Long messageId);
}
