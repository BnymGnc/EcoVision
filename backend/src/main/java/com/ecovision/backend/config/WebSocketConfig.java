package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.security.JwtService;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private static final Pattern GROUP_TOPIC =
            Pattern.compile("^/topic/groups/(\\d+)(?:/typing)?$");

    private final JwtService jwtService;
    private final AppUserRepository users;
    private final GroupMemberRepository groupMembers;
    private final List<String> allowedOrigins;

    public WebSocketConfig(
            JwtService jwtService,
            AppUserRepository users,
            GroupMemberRepository groupMembers,
            @Value("${app.cors.allowed-origin-patterns}") List<String> allowedOrigins
    ) {
        this.jwtService = jwtService;
        this.users = users;
        this.groupMembers = groupMembers;
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns(allowedOrigins.toArray(String[]::new));
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = StompHeaderAccessor.wrap(message);
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    authenticate(accessor);
                } else if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
                    authorizeSubscription(accessor);
                }
                return message;
            }
        });
    }

    private void authorizeSubscription(StompHeaderAccessor accessor) {
        Matcher matcher = GROUP_TOPIC.matcher(
                accessor.getDestination() == null ? "" : accessor.getDestination()
        );
        if (!matcher.matches()) {
            throw new IllegalArgumentException("Geçersiz sohbet aboneliği");
        }
        if (!(accessor.getUser() instanceof UsernamePasswordAuthenticationToken auth)
                || !(auth.getPrincipal() instanceof AppUser user)
                || !groupMembers.existsByGroupIdAndUserId(
                        Long.parseLong(matcher.group(1)),
                        user.getId()
                )) {
            throw new IllegalArgumentException(
                    "Bu grup sohbetini dinleme yetkiniz yok"
            );
        }
    }

    private void authenticate(StompHeaderAccessor accessor) {
        String header = accessor.getFirstNativeHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            throw new IllegalArgumentException(
                    "WebSocket kimlik doğrulaması gerekli"
            );
        }
        String token = header.substring(7);
        AppUser user = users.findByEmail(jwtService.extractEmail(token))
                .orElseThrow(() -> new IllegalArgumentException(
                        "WebSocket kullanıcısı bulunamadı"
                ));
        if (!jwtService.isValid(token, user) || !user.isAccountNonLocked()) {
            throw new IllegalArgumentException("WebSocket oturumu geçersiz");
        }
        accessor.setUser(new UsernamePasswordAuthenticationToken(
                user,
                null,
                user.getAuthorities()
        ));
    }
}
