package com.ecovision.backend.repository;

import com.ecovision.backend.model.ChatMessage;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByEventIdOrderByTimestampAsc(Long eventId);
}
