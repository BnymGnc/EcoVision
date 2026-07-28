package com.ecovision.backend.dto;

import com.ecovision.backend.model.ChatMessage;
import java.time.Instant;

public record ChatMessageResponse(
        Long id,
        Long eventId,
        Long groupId,
        Long senderId,
        String senderUsername,
        String senderName,
        Integer senderAvatarLevel,
        String senderProfilePictureUrl,
        String message,
        String imageUrl,
        String fileUrl,
        String fileName,
        String contentType,
        String messageType,
        Instant timestamp
) {
    public static ChatMessageResponse from(ChatMessage message) {
        return new ChatMessageResponse(
                message.getId(),
                message.getEvent() == null ? null : message.getEvent().getId(),
                message.getGroup() == null ? null : message.getGroup().getId(),
                message.getSender().getId(),
                message.getSender().getPublicUsername(),
                message.getSender().getName() + " " + message.getSender().getSurname(),
                message.getSender().getEquippedAvatarLevel(),
                message.getSender().getProfilePictureUrl(),
                message.getMessage(),
                message.getImageUrl(),
                message.getFileUrl(),
                message.getFileName(),
                message.getContentType(),
                message.getMessageType().name(),
                message.getTimestamp()
        );
    }
}
