package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.AppUserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ChatService {
    private final ChatMessageRepository chatMessageRepository;
    private final EventRepository eventRepository;
    private final AppUserRepository userRepository;
    private final EventMemberRepository eventMemberRepository;
    private final AgeGateService ageGateService;
    private final FileStorageService fileStorageService;

    public ChatService(
            ChatMessageRepository chatMessageRepository,
            EventRepository eventRepository,
            AppUserRepository userRepository,
            EventMemberRepository eventMemberRepository,
            AgeGateService ageGateService,
            FileStorageService fileStorageService
    ) {
        this.chatMessageRepository = chatMessageRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
        this.eventMemberRepository = eventMemberRepository;
        this.ageGateService = ageGateService;
        this.fileStorageService = fileStorageService;
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> getMessages(
            AppUser user,
            Long eventId,
            int limit,
            int offset
    ) {
        requireMember(user, eventId);
        int safeLimit = Math.min(Math.max(limit, 1), 100);
        int safeOffset = Math.max(offset, 0);
        List<ChatMessage> messages = new ArrayList<>(chatMessageRepository
                .findByEventIdOrderByTimestampDesc(
                        eventId,
                        PageRequest.of(safeOffset / safeLimit, safeLimit)
                )
                .getContent());
        Collections.reverse(messages);
        return messages.stream()
                .map(ChatMessageResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public long unreadCount(AppUser user) {
        ageGateService.requireAdult(user);
        Instant since = user.getCommunityReadAt() == null
                ? Instant.EPOCH
                : user.getCommunityReadAt();
        return chatMessageRepository.countUnreadForMember(user.getId(), since);
    }

    @Transactional
    public void markCommunityRead(AppUser currentUser) {
        ageGateService.requireAdult(currentUser);
        AppUser user = userRepository.findByIdForUpdate(currentUser.getId())
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        user.setCommunityReadAt(Instant.now());
        userRepository.save(user);
    }

    @Transactional
    public ChatMessageResponse sendMessage(AppUser sender, Long eventId, ChatMessageRequest request) {
        requireMember(sender, eventId);
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Etkinlik bulunamadı"));

        ChatMessage message = new ChatMessage();
        message.setEvent(event);
        message.setSender(sender);
        message.setMessage(request.message());

        return ChatMessageResponse.from(chatMessageRepository.save(message));
    }

    @Transactional
    public ChatMessageResponse sendImage(AppUser sender, Long eventId, MultipartFile image) {
        requireMember(sender, eventId);
        if (image == null || image.isEmpty()) throw new IllegalArgumentException("Bir fotoğraf seçmelisiniz");
        if (image.getSize() > 2L * 1024 * 1024) throw new IllegalArgumentException("Fotoğraf 2 MB'den küçük olmalıdır");
        String contentType = image.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) throw new IllegalArgumentException("Yalnızca fotoğraf yüklenebilir");
        Event event = eventRepository.findById(eventId).orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
        ChatMessage message = new ChatMessage();
        message.setEvent(event); message.setSender(sender); message.setMessage("");
        message.setImageUrl(fileStorageService.store(image, "chat"));
        return ChatMessageResponse.from(chatMessageRepository.save(message));
    }

    private void requireMember(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        if (!eventMemberRepository.existsByEventIdAndUserId(eventId, user.getId())) {
            throw new IllegalArgumentException("Bu sohbet yalnızca grup üyelerine açıktır");
        }
    }
}
