package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppNotification;
import java.time.Instant;

public record NotificationResponse(Long id, String title, String message, String type, boolean read, Instant createdAt) {
    public static NotificationResponse from(AppNotification notification) {
        return new NotificationResponse(notification.getId(), notification.getTitle(), notification.getMessage(),
                notification.getType().name(), notification.isRead(), notification.getCreatedAt());
    }
}
