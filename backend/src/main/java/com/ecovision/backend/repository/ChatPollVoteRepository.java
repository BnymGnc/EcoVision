package com.ecovision.backend.repository;

import com.ecovision.backend.model.ChatPollVote;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatPollVoteRepository extends JpaRepository<ChatPollVote, Long> {
    Optional<ChatPollVote> findByPollIdAndUserId(Long pollId, Long userId);

    @EntityGraph(attributePaths = "user")
    List<ChatPollVote> findByPollId(Long pollId);
}
