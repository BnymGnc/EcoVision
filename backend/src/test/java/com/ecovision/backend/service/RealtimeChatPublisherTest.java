package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import com.ecovision.backend.dto.ChatMessageResponse;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessagingTemplate;

class RealtimeChatPublisherTest {
    @Test
    void brokerFailureDoesNotFailCommittedMessageRequest() {
        MessageChannel failingChannel = new MessageChannel() {
            @Override
            public boolean send(Message<?> message) {
                throw new IllegalStateException("broker unavailable");
            }

            @Override
            public boolean send(Message<?> message, long timeout) {
                throw new IllegalStateException("broker unavailable");
            }
        };
        SimpMessagingTemplate messaging =
                new SimpMessagingTemplate(failingChannel);
        RealtimeChatPublisher publisher = new RealtimeChatPublisher(messaging);
        ChatMessageResponse message = new ChatMessageResponse(
                12L,
                null,
                9L,
                null,
                3L,
                "test8",
                "Test Kullanıcı",
                1,
                null,
                "Merhaba",
                null,
                null,
                null,
                null,
                null,
                "USER",
                Instant.now(),
                false,
                null,
                null,
                null,
                null,
                List.of(),
                null
        );

        assertDoesNotThrow(() -> publisher.publishAfterCommit(message));
    }
}
