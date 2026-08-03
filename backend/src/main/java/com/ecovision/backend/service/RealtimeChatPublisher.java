package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.dto.EventTypingEventResponse;
import com.ecovision.backend.dto.TypingEventResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
public class RealtimeChatPublisher {
    private static final Logger log =
            LoggerFactory.getLogger(RealtimeChatPublisher.class);

    private final SimpMessagingTemplate messaging;

    public RealtimeChatPublisher(SimpMessagingTemplate messaging) {
        this.messaging = messaging;
    }

    public void publishAfterCommit(ChatMessageResponse message) {
        Runnable publish = () -> {
            if (message.groupId() != null) {
                try {
                    messaging.convertAndSend(
                            "/topic/groups/" + message.groupId(),
                            message
                    );
                } catch (RuntimeException exception) {
                    // A broker hiccup must not turn an already committed chat
                    // message or group event into an HTTP 500 response.
                    log.error(
                            "Realtime publish failed for group={} message={}",
                            message.groupId(),
                            message.id(),
                            exception
                    );
                }
            } else if (message.eventId() != null) {
                try {
                    messaging.convertAndSend(
                            "/topic/events/" + message.eventId(),
                            message
                    );
                } catch (RuntimeException exception) {
                    log.error(
                            "Realtime publish failed for event={} message={}",
                            message.eventId(),
                            message.id(),
                            exception
                    );
                }
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(
                    new TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            publish.run();
                        }
                    }
            );
        } else {
            publish.run();
        }
    }

    public void publishTyping(TypingEventResponse event) {
        try {
            messaging.convertAndSend(
                    "/topic/groups/" + event.groupId() + "/typing",
                    event
            );
        } catch (RuntimeException exception) {
            log.debug(
                    "Typing event publish failed for group={}",
                    event.groupId(),
                    exception
            );
        }
    }

    public void publishEventTyping(EventTypingEventResponse event) {
        try {
            messaging.convertAndSend(
                    "/topic/events/" + event.eventId() + "/typing",
                    event
            );
        } catch (RuntimeException exception) {
            log.debug(
                    "Typing event publish failed for event={}",
                    event.eventId(),
                    exception
            );
        }
    }
}
