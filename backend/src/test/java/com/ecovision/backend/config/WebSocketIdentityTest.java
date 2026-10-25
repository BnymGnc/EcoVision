package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.*;
import com.ecovision.backend.security.JwtService;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.messaging.support.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class WebSocketIdentityTest {
    @Test void connectSetsTheOriginalPrincipalAndMembershipRemainsRequired() {
        var jwt = mock(JwtService.class); var users = mock(AppUserRepository.class);
        var members = mock(GroupMemberRepository.class);
        var events = mock(EventMemberRepository.class);
        var config = new WebSocketConfig(jwt, users, members, events, List.of("*"));
        var registration = mock(ChannelRegistration.class);
        config.configureClientInboundChannel(registration);
        var capture = ArgumentCaptor.forClass(ChannelInterceptor.class);
        verify(registration).interceptors(capture.capture());
        var interceptor = capture.getValue();
        var user = new AppUser(); user.setId(1L); user.setEmail("ws@ecovision.invalid"); user.setAge(24);
        when(jwt.extractEmail("local-test-token")).thenReturn(user.getEmail());
        when(users.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(jwt.isValid("local-test-token", user)).thenReturn(true);
        var connect = StompHeaderAccessor.create(StompCommand.CONNECT);
        connect.setNativeHeader("Authorization", "Bearer local-test-token"); connect.setLeaveMutable(true);
        var message = MessageBuilder.createMessage(new byte[0], connect.getMessageHeaders());
        interceptor.preSend(message, mock(org.springframework.messaging.MessageChannel.class));
        assertNotNull(connect.getUser(), "The original CONNECT accessor must retain authentication");
        assertEquals(user.getEmail(), connect.getUser().getName());
        var subscribe = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        subscribe.setUser(connect.getUser()); subscribe.setDestination("/topic/groups/5"); subscribe.setLeaveMutable(true);
        var subscription = MessageBuilder.createMessage(new byte[0], subscribe.getMessageHeaders());
        assertThrows(IllegalArgumentException.class, () -> interceptor.preSend(subscription, mock(org.springframework.messaging.MessageChannel.class)));
        when(members.existsByGroupIdAndUserId(5L, 1L)).thenReturn(true);
        assertSame(subscription, interceptor.preSend(subscription, mock(org.springframework.messaging.MessageChannel.class)));
    }
}
