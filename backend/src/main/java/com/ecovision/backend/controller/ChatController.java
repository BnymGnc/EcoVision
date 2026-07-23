package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.service.ChatService;
import com.ecovision.backend.service.CurrentUserService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

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
    public List<ChatMessageResponse> messages(
            @PathVariable Long eventId,
            @RequestParam(defaultValue = "30") int limit,
            @RequestParam(defaultValue = "0") int offset
    ) {
        return chatService.getMessages(
                currentUserService.currentUser(),
                eventId,
                limit,
                offset
        );
    }

    @GetMapping("/unread-count")
    public Map<String, Long> unreadCount() {
        return Map.of("count", chatService.unreadCount(currentUserService.currentUser()));
    }

    @PostMapping("/read")
    public Map<String, Boolean> markRead() {
        chatService.markCommunityRead(currentUserService.currentUser());
        return Map.of("success", true);
    }

    @PostMapping("/events/{eventId}")
    public ChatMessageResponse sendMessage(
            @PathVariable Long eventId,
            @Valid @RequestBody ChatMessageRequest request
    ) {
        return chatService.sendMessage(currentUserService.currentUser(), eventId, request);
    }

    @PostMapping(value = "/events/{eventId}/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ChatMessageResponse sendImage(@PathVariable Long eventId, @RequestPart("image") MultipartFile image) {
        return chatService.sendImage(currentUserService.currentUser(), eventId, image);
    }

    @PostMapping(
            value = "/events/{eventId}/attachments",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ChatMessageResponse sendAttachment(
            @PathVariable Long eventId,
            @RequestPart("file") MultipartFile file
    ) {
        return chatService.sendAttachment(currentUserService.currentUser(), eventId, file);
    }
}
