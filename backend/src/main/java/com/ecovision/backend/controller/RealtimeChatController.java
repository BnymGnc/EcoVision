package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.EventTypingEventResponse;
import com.ecovision.backend.dto.TypingEventRequest;
import com.ecovision.backend.dto.TypingEventResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.service.ChatService;
import com.ecovision.backend.service.RealtimeChatPublisher;
import jakarta.validation.Valid;
import java.security.Principal;
import java.time.Instant;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.stereotype.Controller;

@Controller
public class RealtimeChatController {
    private final ChatService chatService;
    private final AppUserRepository users;
    private final RealtimeChatPublisher publisher;

    public RealtimeChatController(
            ChatService chatService,
            AppUserRepository users,
            RealtimeChatPublisher publisher
    ) {
        this.chatService = chatService;
        this.users = users;
        this.publisher = publisher;
    }

    @MessageMapping("/groups/{groupId}/messages")
    public void send(
            @DestinationVariable Long groupId,
            @Valid ChatMessageRequest request,
            Principal principal
    ) {
        if (principal == null) {
            throw new IllegalArgumentException("Sohbet oturumu bulunamadı");
        }
        AppUser user = users.findByEmail(principal.getName())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Kullanıcı bulunamadı"
                ));
        chatService.sendGroupMessage(user, groupId, request);
    }

    @MessageMapping("/events/{eventId}/messages")
    public void sendEventMessage(
            @DestinationVariable Long eventId,
            @Valid ChatMessageRequest request,
            Principal principal
    ) {
        chatService.sendMessage(authenticatedUser(principal), eventId, request);
    }

    @MessageMapping("/groups/{groupId}/typing")
    public void typing(
            @DestinationVariable Long groupId,
            TypingEventRequest request,
            Principal principal
    ) {
        AppUser user = authenticatedUser(principal);
        chatService.requireTypingAccess(user, groupId);
        publisher.publishTyping(new TypingEventResponse(
                groupId,
                user.getId(),
                user.getPublicUsername(),
                user.getName() + " " + user.getSurname(),
                request.typing(),
                Instant.now().plusSeconds(4)
        ));
    }

    @MessageMapping("/events/{eventId}/typing")
    public void eventTyping(
            @DestinationVariable Long eventId,
            TypingEventRequest request,
            Principal principal
    ) {
        AppUser user = authenticatedUser(principal);
        chatService.requireEventTypingAccess(user, eventId);
        publisher.publishEventTyping(new EventTypingEventResponse(
                eventId,
                user.getId(),
                user.getPublicUsername(),
                user.getName() + " " + user.getSurname(),
                request.typing(),
                Instant.now().plusSeconds(4)
        ));
    }

    private AppUser authenticatedUser(Principal principal) {
        if (principal == null) {
            throw new IllegalArgumentException("Sohbet oturumu bulunamadı");
        }
        return users.findByEmail(principal.getName())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Kullanıcı bulunamadı"
                ));
    }
}
