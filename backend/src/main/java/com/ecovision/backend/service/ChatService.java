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
import java.util.Locale;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ChatService {
    private final ChatMessageRepository chatMessageRepository;
    private final EventRepository eventRepository;
    private final AppUserRepository userRepository;
    private final EventMemberRepository eventMemberRepository;
    private final AgeGateService ageGateService;
    private final FileStorageService fileStorageService;
    private final InputSanitizer inputSanitizer;

    public ChatService(
            ChatMessageRepository chatMessageRepository,
            EventRepository eventRepository,
            AppUserRepository userRepository,
            EventMemberRepository eventMemberRepository,
            AgeGateService ageGateService,
            FileStorageService fileStorageService,
            InputSanitizer inputSanitizer
    ) {
        this.chatMessageRepository = chatMessageRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
        this.eventMemberRepository = eventMemberRepository;
        this.ageGateService = ageGateService;
        this.fileStorageService = fileStorageService;
        this.inputSanitizer = inputSanitizer;
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
        message.setMessage(inputSanitizer.plainText(request.message(), "Mesaj", 2000));

        return ChatMessageResponse.from(chatMessageRepository.save(message));
    }

    @Transactional
    public ChatMessageResponse sendImage(AppUser sender, Long eventId, MultipartFile image) {
        return sendAttachment(sender, eventId, image);
    }

    @Transactional
    public ChatMessageResponse sendAttachment(
            AppUser sender,
            Long eventId,
            MultipartFile file
    ) {
        requireMember(sender, eventId);
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Bir fotoğraf veya PDF seçmelisiniz");
        }
        if (file.getSize() > 2L * 1024 * 1024) {
            throw new IllegalArgumentException("Ek dosya 2 MB'den küçük olmalıdır");
        }
        String contentType = file.getContentType() == null
                ? "application/octet-stream"
                : file.getContentType().toLowerCase(Locale.ROOT);
        String originalName = file.getOriginalFilename() == null
                ? "dosya"
                : file.getOriginalFilename();
        boolean image = contentType.startsWith("image/");
        boolean pdf = contentType.equals(MediaType.APPLICATION_PDF_VALUE)
                || originalName.toLowerCase(Locale.ROOT).endsWith(".pdf");
        if (!image && !pdf) {
            throw new IllegalArgumentException("Yalnızca fotoğraf veya PDF yüklenebilir");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
        ChatMessage message = new ChatMessage();
        message.setEvent(event);
        message.setSender(sender);
        message.setMessage("");
        message.setFileName(originalName);
        message.setContentType(image ? contentType : MediaType.APPLICATION_PDF_VALUE);
        String url = fileStorageService.store(file, "chat");
        if (image) {
            message.setImageUrl(url);
        } else {
            message.setFileUrl(url);
        }
        return ChatMessageResponse.from(chatMessageRepository.save(message));
    }

    private void requireMember(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        if (!eventMemberRepository.existsByEventIdAndUserId(eventId, user.getId())) {
            throw new IllegalArgumentException("Bu sohbet yalnızca grup üyelerine açıktır");
        }
    }
}
