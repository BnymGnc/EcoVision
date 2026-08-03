package com.ecovision.backend.dto;

import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.AvatarTier;
import java.time.Instant;
import java.util.List;

public record ChatMessageResponse(
        Long id,
        Long eventId,
        Long groupId,
        Long groupEventId,
        Long senderId,
        String senderUsername,
        String senderName,
        Integer senderAvatarLevel,
        Integer senderHighestAvatarLevel,
        String senderProfilePictureUrl,
        String senderProfileImagePreference,
        String senderSelectedAvatarPath,
        boolean senderAdult,
        String senderProfileVisibility,
        String message,
        String imageUrl,
        String fileUrl,
        String fileName,
        Long fileSizeBytes,
        String contentType,
        String messageType,
        Instant timestamp,
        boolean deleted,
        Long replyToMessageId,
        Long replyToSenderId,
        String replyToSenderName,
        String replyToText,
        List<ChatReactionResponse> reactions,
        ChatPollResponse poll
) {
    public static ChatMessageResponse from(ChatMessage message) {
        return new ChatMessageResponse(
                message.getId(),
                message.getEvent() == null ? null : message.getEvent().getId(),
                message.getGroup() == null ? null : message.getGroup().getId(),
                message.getGroupEvent() == null ? null : message.getGroupEvent().getId(),
                message.getSender().getId(),
                message.getSender().getPublicUsername(),
                message.getSender().getName() + " " + message.getSender().getSurname(),
                message.getSender().getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(
                        message.getSender().getLifetimePoints()
                ).level(),
                ProfileImageDtoPolicy.publicCustomPhoto(message.getSender()),
                message.getSender().getProfileImagePreference().name(),
                message.getSender().getSelectedAvatarPath(),
                message.getSender().isAdult(),
                message.getSender().getProfileVisibility().name(),
                message.getMessage(),
                message.getImageUrl(),
                message.getFileUrl(),
                message.getFileName(),
                message.getFileSizeBytes(),
                message.getContentType(),
                message.getMessageType().name(),
                message.getTimestamp(),
                message.isDeleted(),
                message.getReplyTo() == null ? null : message.getReplyTo().getId(),
                message.getReplyTo() == null ? null : message.getReplyTo().getSender().getId(),
                message.getReplyTo() == null
                        ? null
                        : message.getReplyTo().getSender().getName()
                                + " "
                                + message.getReplyTo().getSender().getSurname(),
                message.getReplyTo() == null ? null : message.getReplyTo().getMessage(),
                List.of(),
                null
        );
    }

    public ChatMessageResponse withRichContent(
            List<ChatReactionResponse> reactionItems,
            ChatPollResponse pollItem
    ) {
        return new ChatMessageResponse(
                id, eventId, groupId, groupEventId, senderId, senderUsername,
                senderName, senderAvatarLevel, senderHighestAvatarLevel,
                senderProfilePictureUrl, senderProfileImagePreference,
                senderSelectedAvatarPath, senderAdult, senderProfileVisibility,
                deleted ? "Bu mesaj silindi" : message,
                deleted ? null : imageUrl,
                deleted ? null : fileUrl,
                deleted ? null : fileName,
                deleted ? null : fileSizeBytes,
                deleted ? null : contentType,
                messageType, timestamp, deleted, replyToMessageId,
                replyToSenderId, replyToSenderName, replyToText,
                reactionItems == null ? List.of() : reactionItems,
                deleted ? null : pollItem
        );
    }
}
