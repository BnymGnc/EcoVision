package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatService {
    private final ChatMessageRepository chatMessageRepository;
    private final EventRepository eventRepository;

    public ChatService(ChatMessageRepository chatMessageRepository, EventRepository eventRepository) {
        this.chatMessageRepository = chatMessageRepository;
        this.eventRepository = eventRepository;
    }

    public List<ChatMessageResponse> getMessages(Long eventId) {
        return chatMessageRepository.findByEventIdOrderByTimestampAsc(eventId)
                .stream()
                .map(ChatMessageResponse::from)
                .toList();
    }

    @Transactional
    public ChatMessageResponse sendMessage(AppUser sender, Long eventId, ChatMessageRequest request) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Event not found"));

        ChatMessage message = new ChatMessage();
        message.setEvent(event);
        message.setSender(sender);
        message.setMessage(request.message());

        return ChatMessageResponse.from(chatMessageRepository.save(message));
    }
}
