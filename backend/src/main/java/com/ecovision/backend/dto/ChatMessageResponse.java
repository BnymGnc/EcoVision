package com.ecovision.backend.dto;

import com.ecovision.backend.model.ChatMessage;
import java.time.Instant;

public record ChatMessageResponse(
        Long id,
        Long eventId,
        Long senderId,
        String senderName,
        Integer senderAvatarLevel,
        String senderProfilePictureUrl,
        String message,
        String imageUrl,
        Instant timestamp
) {
    public static ChatMessageResponse from(ChatMessage message) {
        return new ChatMessageResponse(
                message.getId(),
                message.getEvent().getId(),
                message.getSender().getId(),
                message.getSender().getName() + " " + message.getSender().getSurname(),
                message.getSender().getEquippedAvatarLevel(),
                message.getSender().getProfilePictureUrl(),
                message.getMessage(),
                message.getImageUrl(),
                message.getTimestamp()
        );
    }
}
