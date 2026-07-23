package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.BadgeType;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupActivityMessageService {
    private final EventMemberRepository memberRepository;
    private final ChatMessageRepository messageRepository;

    public GroupActivityMessageService(
            EventMemberRepository memberRepository,
            ChatMessageRepository messageRepository
    ) {
        this.memberRepository = memberRepository;
        this.messageRepository = messageRepository;
    }

    @Transactional
    public void publishBadge(AppUser user, BadgeType badge) {
        publish(
                user,
                ChatMessageType.SYSTEM_BADGE,
                "🎉 @" + username(user) + ", " + badge.title() + " rozetini kazandı!"
        );
    }

    @Transactional
    public void publishLevel(AppUser user, AvatarTier tier) {
        publish(
                user,
                ChatMessageType.SYSTEM_LEVEL,
                "🌱 @" + username(user) + ", Seviye " + tier.level()
                        + " - " + tier.title() + " seviyesine ulaştı!"
        );
    }

    private void publish(AppUser user, ChatMessageType type, String text) {
        Map<Long, Event> groups = new LinkedHashMap<>();
        memberRepository.findByUserId(user.getId())
                .forEach(member -> groups.put(member.getEvent().getId(), member.getEvent()));
        if (groups.isEmpty()) {
            return;
        }
        List<ChatMessage> messages = groups.values().stream()
                .map(event -> systemMessage(event, user, type, text))
                .toList();
        messageRepository.saveAll(messages);
    }

    private ChatMessage systemMessage(
            Event event,
            AppUser user,
            ChatMessageType type,
            String text
    ) {
        ChatMessage message = new ChatMessage();
        message.setEvent(event);
        message.setSender(user);
        message.setMessage(text);
        message.setMessageType(type);
        return message;
    }

    private String username(AppUser user) {
        return user.getPublicUsername() == null
                ? user.getName().toLowerCase()
                : user.getPublicUsername();
    }
}
