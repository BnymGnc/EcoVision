package com.ecovision.backend.service;

import com.ecovision.backend.model.QuestTriggerType;
import java.time.Instant;
import java.util.Map;

public record QuestEvent(
        Long userId,
        QuestTriggerType triggerType,
        int amount,
        Instant occurredAt,
        Map<String, Object> attributes
) {
    public QuestEvent {
        if (userId == null || userId < 1) {
            throw new IllegalArgumentException("Görev olayı için kullanıcı zorunludur");
        }
        if (triggerType == null) {
            throw new IllegalArgumentException("Görev tetikleyici türü zorunludur");
        }
        amount = Math.max(0, amount);
        occurredAt = occurredAt == null ? Instant.now() : occurredAt;
        attributes = attributes == null ? Map.of() : Map.copyOf(attributes);
    }

    public static QuestEvent of(
            Long userId,
            QuestTriggerType triggerType,
            int amount,
            Map<String, Object> attributes
    ) {
        return new QuestEvent(
                userId,
                triggerType,
                amount,
                Instant.now(),
                attributes
        );
    }
}
