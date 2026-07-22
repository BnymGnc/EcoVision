package com.ecovision.backend.repository;

import com.ecovision.backend.model.ChatMessage;
import java.util.List;
import java.time.Instant;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    @EntityGraph(attributePaths = {"event", "sender"})
    Page<ChatMessage> findByEventIdOrderByTimestampDesc(Long eventId, Pageable pageable);

    @EntityGraph(attributePaths = {"event", "sender"})
    Page<ChatMessage> findBySenderIdOrderByTimestampDesc(Long senderId, Pageable pageable);

    @Query("""
            select count(message) from ChatMessage message
            where message.sender.id <> :userId
              and message.timestamp > :timestamp
              and exists (
                  select member.id from EventMember member
                  where member.event.id = message.event.id and member.user.id = :userId
              )
            """)
    long countUnreadForMember(@Param("userId") Long userId, @Param("timestamp") Instant timestamp);

    void deleteByEventId(Long eventId);
}
