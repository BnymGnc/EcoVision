package com.ecovision.backend.repository;

import com.ecovision.backend.model.ChatPoll;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatPollRepository extends JpaRepository<ChatPoll, Long> {
    @EntityGraph(attributePaths = "options")
    Optional<ChatPoll> findByMessageId(Long messageId);
}
