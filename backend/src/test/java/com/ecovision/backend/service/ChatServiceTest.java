package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.dto.CreatePollRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.ChatPoll;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.ChatPollRepository;
import com.ecovision.backend.repository.ChatPollVoteRepository;
import com.ecovision.backend.repository.ChatReactionRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessagingTemplate;

@ExtendWith(MockitoExtension.class)
class ChatServiceTest {
    @Mock private ChatMessageRepository messages;
    @Mock private EventRepository events;
    @Mock private AppUserRepository users;
    @Mock private EventMemberRepository eventMembers;
    @Mock private CommunityGroupRepository groups;
    @Mock private GroupMemberRepository groupMembers;
    @Mock private ChatReactionRepository reactions;
    @Mock private ChatPollRepository polls;
    @Mock private ChatPollVoteRepository pollVotes;

    private ChatService service;
    private RealtimeChatPublisher publisher;
    private AppUser user;
    private CommunityGroup group;

    @BeforeEach
    void setUp() {
        MessageChannel channel = new MessageChannel() {
            @Override
            public boolean send(Message<?> message) {
                return true;
            }

            @Override
            public boolean send(Message<?> message, long timeout) {
                return true;
            }
        };
        publisher = new RealtimeChatPublisher(
                new SimpMessagingTemplate(channel)
        );
        service = new ChatService(
                messages,
                events,
                users,
                eventMembers,
                groups,
                groupMembers,
                new AgeGateService(),
                null,
                new InputSanitizer(),
                publisher,
                reactions,
                polls,
                pollVotes
        );
        user = new AppUser();
        user.setId(7L);
        user.setAge(25);
        user.setName("Test");
        user.setSurname("Üye");
        user.setPublicUsername("testuye");
        group = new CommunityGroup();
        group.setCreator(user);
        group.setName("Test Grubu");
        GroupMember membership = new GroupMember();
        membership.setGroup(group);
        membership.setUser(user);
        membership.setRole(GroupRole.MEMBER);
        when(groupMembers.findByGroupIdAndUserId(10L, 7L))
                .thenReturn(Optional.of(membership));
        lenient().when(groups.findById(10L)).thenReturn(Optional.of(group));
        when(messages.save(any(ChatMessage.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void regularMemberCanSendGroupMessage() {
        ChatMessageResponse response = service.sendGroupMessage(
                user,
                10L,
                new ChatMessageRequest("Merhaba grup", null)
        );

        assertEquals("Merhaba grup", response.message());
        assertEquals("USER", response.messageType());
    }

    @Test
    void adminCanCreatePoll() {
        GroupMember admin = groupMembers.findByGroupIdAndUserId(10L, 7L)
                .orElseThrow();
        admin.setRole(GroupRole.ADMIN);
        when(polls.save(any(ChatPoll.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        service.createPoll(
                user,
                10L,
                new CreatePollRequest(
                        "Hafta sonu buluşalım mı?",
                        List.of("Evet", "Hayır")
                )
        );

        ArgumentCaptor<ChatMessage> messageCaptor =
                ArgumentCaptor.forClass(ChatMessage.class);
        verify(messages).save(messageCaptor.capture());
        assertEquals(
                ChatMessageType.POLL,
                messageCaptor.getValue().getMessageType()
        );
        verify(polls).save(any(ChatPoll.class));
    }

    @Test
    void pollCreatorCanDeletePoll() {
        ChatMessage message = new ChatMessage();
        message.setGroup(group);
        message.setSender(user);
        message.setMessage("Test anketi");
        message.setMessageType(ChatMessageType.POLL);
        ChatPoll poll = new ChatPoll();
        poll.setMessage(message);
        poll.setQuestion("Test anketi");
        poll.setOptions(List.of("Evet", "Hayır"));
        when(messages.findByIdAndGroupId(22L, 10L))
                .thenReturn(Optional.of(message));
        when(polls.findByMessageId(22L)).thenReturn(Optional.of(poll));

        ChatMessageResponse response = service.deletePoll(user, 10L, 22L);

        assertEquals(true, response.deleted());
        verify(pollVotes).deleteByPollId(poll.getId());
        verify(polls).delete(poll);
    }
}
