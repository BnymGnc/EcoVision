package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.service.ChatService;
import com.ecovision.backend.service.CurrentUserService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/chat")
public class ChatController {
    private final ChatService chatService;
    private final CurrentUserService currentUserService;

    public ChatController(ChatService chatService, CurrentUserService currentUserService) {
        this.chatService = chatService;
        this.currentUserService = currentUserService;
    }

    @GetMapping("/events/{eventId}")
    public List<ChatMessageResponse> messages(@PathVariable Long eventId) {
        return chatService.getMessages(eventId);
    }

    @PostMapping("/events/{eventId}")
    public ChatMessageResponse sendMessage(
            @PathVariable Long eventId,
            @Valid @RequestBody ChatMessageRequest request
    ) {
        return chatService.sendMessage(currentUserService.currentUser(), eventId, request);
    }
}
