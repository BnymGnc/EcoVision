package com.ecovision.backend.service;

import com.ecovision.backend.model.QuestTriggerType;
import java.util.Map;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
public class QuestEventPublisher {
    private final ApplicationEventPublisher publisher;

    public QuestEventPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    public void publish(
            Long userId,
            QuestTriggerType triggerType,
            int amount,
            Map<String, Object> attributes
    ) {
        publisher.publishEvent(
                QuestEvent.of(userId, triggerType, amount, attributes)
        );
    }
}
