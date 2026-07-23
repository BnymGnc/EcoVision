package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.BadgeType;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.model.EventMember;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GroupActivityMessageServiceTest {
    @Mock
    private EventMemberRepository memberRepository;

    @Mock
    private ChatMessageRepository messageRepository;

    private GroupActivityMessageService service;

    @BeforeEach
    void setUp() {
        service = new GroupActivityMessageService(memberRepository, messageRepository);
    }

    @Test
    void badgeAwardCreatesTypedMessageInEveryGroup() {
        AppUser user = new AppUser();
        user.setId(5L);
        user.setPublicUsername("ada");
        Event event = new Event();
        event.setId(11L);
        EventMember member = new EventMember();
        member.setEvent(event);
        member.setUser(user);
        when(memberRepository.findByUserId(5L)).thenReturn(List.of(member));

        service.publishBadge(user, BadgeType.PLASTIC_HUNTER);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Iterable<ChatMessage>> captor = ArgumentCaptor.forClass(Iterable.class);
        verify(messageRepository).saveAll(captor.capture());
        ChatMessage message = captor.getValue().iterator().next();
        assertEquals(ChatMessageType.SYSTEM_BADGE, message.getMessageType());
        assertTrue(message.getMessage().contains("@ada"));
        assertTrue(message.getMessage().contains("Plastik Avcısı"));
    }
}
