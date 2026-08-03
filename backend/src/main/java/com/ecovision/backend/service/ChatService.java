package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChatMessageRequest;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.dto.ChatPollOptionResponse;
import com.ecovision.backend.dto.ChatPollResponse;
import com.ecovision.backend.dto.ChatReactionResponse;
import com.ecovision.backend.dto.CreatePollRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.ChatPoll;
import com.ecovision.backend.model.ChatPollVote;
import com.ecovision.backend.model.ChatReaction;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.repository.ChatPollRepository;
import com.ecovision.backend.repository.ChatPollVoteRepository;
import com.ecovision.backend.repository.ChatReactionRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.repository.AppUserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ChatService {
    private final ChatMessageRepository chatMessageRepository;
    private final EventRepository eventRepository;
    private final AppUserRepository userRepository;
    private final EventMemberRepository eventMemberRepository;
    private final CommunityGroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final AgeGateService ageGateService;
    private final FileStorageService fileStorageService;
    private final InputSanitizer inputSanitizer;
    private final RealtimeChatPublisher realtimePublisher;
    private final ChatReactionRepository reactions;
    private final ChatPollRepository polls;
    private final ChatPollVoteRepository pollVotes;

    public ChatService(
            ChatMessageRepository chatMessageRepository,
            EventRepository eventRepository,
            AppUserRepository userRepository,
            EventMemberRepository eventMemberRepository,
            CommunityGroupRepository groupRepository,
            GroupMemberRepository groupMemberRepository,
            AgeGateService ageGateService,
            FileStorageService fileStorageService,
            InputSanitizer inputSanitizer,
            RealtimeChatPublisher realtimePublisher,
            ChatReactionRepository reactions,
            ChatPollRepository polls,
            ChatPollVoteRepository pollVotes
    ) {
        this.chatMessageRepository = chatMessageRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
        this.eventMemberRepository = eventMemberRepository;
        this.groupRepository = groupRepository;
        this.groupMemberRepository = groupMemberRepository;
        this.ageGateService = ageGateService;
        this.fileStorageService = fileStorageService;
        this.inputSanitizer = inputSanitizer;
        this.realtimePublisher = realtimePublisher;
        this.reactions = reactions;
        this.polls = polls;
        this.pollVotes = pollVotes;
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

        return saveAndPublish(message);
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
        boolean image = isSafeImage(contentType);
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
        message.setFileSizeBytes(file.getSize());
        message.setContentType(image ? contentType : MediaType.APPLICATION_PDF_VALUE);
        String url = fileStorageService.store(file, "chat");
        if (image) {
            message.setImageUrl(url);
        } else {
            message.setFileUrl(url);
        }
        return saveAndPublish(message);
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> getGroupMessages(
            AppUser user,
            Long groupId,
            int limit,
            int offset
    ) {
        requireGroupMember(user, groupId);
        int safeLimit = Math.min(Math.max(limit, 1), 100);
        int safeOffset = Math.max(offset, 0);
        List<ChatMessage> messages = new ArrayList<>(chatMessageRepository
                .findByGroupIdOrderByTimestampDesc(
                        groupId,
                        PageRequest.of(safeOffset / safeLimit, safeLimit)
                )
                .getContent());
        Collections.reverse(messages);
        return messages.stream().map(this::richResponse).toList();
    }

    @Transactional
    public ChatMessageResponse sendGroupMessage(
            AppUser sender,
            Long groupId,
            ChatMessageRequest request
    ) {
        requireGroupMember(sender, groupId);
        CommunityGroup group = groupRepository.findById(groupId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
        ChatMessage message = new ChatMessage();
        message.setGroup(group);
        message.setSender(sender);
        message.setMessage(inputSanitizer.plainText(request.message(), "Mesaj", 2000));
        message.setReplyTo(resolveReply(groupId, request.replyToMessageId()));
        return saveAndPublish(message);
    }

    @Transactional
    public ChatMessageResponse sendGroupAttachment(
            AppUser sender,
            Long groupId,
            MultipartFile file,
            Long replyToMessageId
    ) {
        requireGroupMember(sender, groupId);
        validateAttachment(file);
        CommunityGroup group = groupRepository.findById(groupId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
        String contentType = file.getContentType() == null
                ? "application/octet-stream"
                : file.getContentType().toLowerCase(Locale.ROOT);
        String originalName = file.getOriginalFilename() == null
                ? "dosya"
                : file.getOriginalFilename();
        boolean image = isSafeImage(contentType);
        ChatMessage message = new ChatMessage();
        message.setGroup(group);
        message.setSender(sender);
        message.setMessage("");
        message.setReplyTo(resolveReply(groupId, replyToMessageId));
        message.setFileName(originalName);
        message.setFileSizeBytes(file.getSize());
        message.setContentType(image ? contentType : MediaType.APPLICATION_PDF_VALUE);
        String url = fileStorageService.store(file, "group-chat");
        if (image) {
            message.setImageUrl(url);
        } else {
            message.setFileUrl(url);
        }
        return saveAndPublish(message);
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> getGroupMedia(
            AppUser user,
            Long groupId,
            int limit,
            int offset
    ) {
        requireGroupMember(user, groupId);
        int safeLimit = Math.min(Math.max(limit, 1), 100);
        int safeOffset = Math.max(offset, 0);
        return chatMessageRepository
                .findByGroupIdAndImageUrlIsNotNullOrderByTimestampDesc(
                        groupId,
                        PageRequest.of(safeOffset / safeLimit, safeLimit)
                )
                .getContent().stream()
                .filter(message -> !message.isDeleted())
                .map(this::richResponse)
                .toList();
    }

    @Transactional
    public ChatMessageResponse react(
            AppUser user,
            Long groupId,
            Long messageId,
            String emoji
    ) {
        requireGroupMember(user, groupId);
        if (!Set.of("👍", "❤️", "👏", "😂").contains(emoji)) {
            throw new IllegalArgumentException("Desteklenmeyen tepki");
        }
        ChatMessage message = findGroupMessage(groupId, messageId);
        if (message.isDeleted()) {
            throw new IllegalArgumentException("Silinmiş mesaja tepki verilemez");
        }
        ChatReaction reaction = reactions.findByMessageIdAndUserId(
                messageId,
                user.getId()
        ).orElseGet(ChatReaction::new);
        if (reaction.getId() != null && emoji.equals(reaction.getEmoji())) {
            reactions.delete(reaction);
        } else {
            reaction.setMessage(message);
            reaction.setUser(user);
            reaction.setEmoji(emoji);
            reactions.save(reaction);
        }
        return publishRich(message);
    }

    @Transactional
    public ChatMessageResponse createPoll(
            AppUser user,
            Long groupId,
            CreatePollRequest request
    ) {
        requireGroupAdmin(user, groupId);
        if (request.options() == null || request.options().size() < 2
                || request.options().size() > 4) {
            throw new IllegalArgumentException("Anket 2 ile 4 seçenek içermelidir");
        }
        CommunityGroup group = groupRepository.findById(groupId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
        ChatMessage message = new ChatMessage();
        message.setGroup(group);
        message.setSender(user);
        message.setMessage(inputSanitizer.plainText(
                request.question(),
                "Anket sorusu",
                300
        ));
        message.setMessageType(ChatMessageType.POLL);
        message = chatMessageRepository.save(message);

        ChatPoll poll = new ChatPoll();
        poll.setMessage(message);
        poll.setQuestion(message.getMessage());
        poll.setOptions(request.options().stream()
                .map(option -> inputSanitizer.plainText(
                        option,
                        "Anket seçeneği",
                        160
                ))
                .toList());
        polls.save(poll);
        return publishRich(message);
    }

    @Transactional
    public ChatMessageResponse vote(
            AppUser user,
            Long groupId,
            Long messageId,
            int optionIndex
    ) {
        requireGroupMember(user, groupId);
        ChatMessage message = findGroupMessage(groupId, messageId);
        ChatPoll poll = polls.findByMessageId(messageId)
                .orElseThrow(() -> new IllegalArgumentException("Anket bulunamadı"));
        if (optionIndex < 0 || optionIndex >= poll.getOptions().size()) {
            throw new IllegalArgumentException("Geçersiz anket seçeneği");
        }
        ChatPollVote vote = pollVotes.findByPollIdAndUserId(
                poll.getId(),
                user.getId()
        ).orElseGet(ChatPollVote::new);
        vote.setPoll(poll);
        vote.setUser(user);
        vote.setOptionIndex(optionIndex);
        pollVotes.save(vote);
        return publishRich(message);
    }

    @Transactional
    public ChatMessageResponse deletePoll(
            AppUser user,
            Long groupId,
            Long messageId
    ) {
        GroupMember actor = requireGroupMemberRecord(user, groupId);
        ChatMessage message = findGroupMessage(groupId, messageId);
        ChatPoll poll = polls.findByMessageId(messageId)
                .orElseThrow(() -> new IllegalArgumentException("Anket bulunamadı"));
        boolean creator = message.getSender().getId().equals(user.getId());
        if (!creator && !isAdmin(actor.getRole())) {
            throw new AccessDeniedException("Bu anketi silme yetkiniz yok");
        }
        pollVotes.deleteByPollId(poll.getId());
        polls.delete(poll);
        message.setDeleted(true);
        message.setDeletedAt(Instant.now());
        chatMessageRepository.save(message);
        return publishRich(message);
    }

    @Transactional
    public ChatMessageResponse deleteGroupMessage(
            AppUser user,
            Long groupId,
            Long messageId
    ) {
        GroupMember actor = requireGroupMemberRecord(user, groupId);
        ChatMessage message = findGroupMessage(groupId, messageId);
        boolean ownMessage = message.getSender().getId().equals(user.getId());
        boolean moderator = isAdmin(actor.getRole());
        if (!ownMessage && !moderator) {
            throw new AccessDeniedException("Bu mesajı silme yetkiniz yok");
        }
        if (message.getMessageType().name().startsWith("SYSTEM_")) {
            throw new AccessDeniedException("Sistem mesajları silinemez");
        }
        message.setDeleted(true);
        message.setDeletedAt(Instant.now());
        chatMessageRepository.save(message);
        return publishRich(message);
    }

    @Transactional(readOnly = true)
    public void requireTypingAccess(AppUser user, Long groupId) {
        requireGroupMember(user, groupId);
    }

    @Transactional(readOnly = true)
    public void requireEventTypingAccess(AppUser user, Long eventId) {
        requireMember(user, eventId);
    }

    private ChatMessageResponse saveAndPublish(ChatMessage message) {
        ChatMessageResponse response = richResponse(chatMessageRepository.save(message));
        realtimePublisher.publishAfterCommit(response);
        return response;
    }

    private ChatMessageResponse publishRich(ChatMessage message) {
        ChatMessageResponse response = richResponse(message);
        realtimePublisher.publishAfterCommit(response);
        return response;
    }

    private ChatMessageResponse richResponse(ChatMessage message) {
        Map<String, List<Long>> grouped = new LinkedHashMap<>();
        reactions.findByMessageId(message.getId()).forEach(reaction ->
                grouped.computeIfAbsent(
                        reaction.getEmoji(),
                        ignored -> new ArrayList<>()
                ).add(reaction.getUser().getId())
        );
        List<ChatReactionResponse> reactionItems = grouped.entrySet().stream()
                .map(entry -> new ChatReactionResponse(
                        entry.getKey(),
                        entry.getValue()
                ))
                .toList();
        ChatPollResponse pollResponse = polls.findByMessageId(message.getId())
                .map(poll -> {
                    List<ChatPollVote> votes = pollVotes.findByPollId(poll.getId());
                    List<ChatPollOptionResponse> options = new ArrayList<>();
                    for (int index = 0; index < poll.getOptions().size(); index++) {
                        int currentIndex = index;
                        options.add(new ChatPollOptionResponse(
                                index,
                                poll.getOptions().get(index),
                                votes.stream()
                                        .filter(vote -> vote.getOptionIndex() == currentIndex)
                                        .map(vote -> vote.getUser().getId())
                                        .toList()
                        ));
                    }
                    return new ChatPollResponse(
                            poll.getId(),
                            poll.getQuestion(),
                            options,
                            votes.size()
                    );
                })
                .orElse(null);
        return ChatMessageResponse.from(message).withRichContent(
                reactionItems,
                pollResponse
        );
    }

    private ChatMessage resolveReply(Long groupId, Long replyToMessageId) {
        if (replyToMessageId == null) {
            return null;
        }
        ChatMessage reply = findGroupMessage(groupId, replyToMessageId);
        if (reply.isDeleted()) {
            throw new IllegalArgumentException("Silinmiş bir mesaja yanıt verilemez");
        }
        return reply;
    }

    private ChatMessage findGroupMessage(Long groupId, Long messageId) {
        return chatMessageRepository.findByIdAndGroupId(messageId, groupId)
                .orElseThrow(() -> new IllegalArgumentException("Mesaj bulunamadı"));
    }

    private void requireMember(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        if (!eventMemberRepository.existsByEventIdAndUserId(eventId, user.getId())) {
            throw new AccessDeniedException(
                    "Bu sohbet yalnızca grup üyelerine açıktır"
            );
        }
    }

    private void requireGroupMember(AppUser user, Long groupId) {
        requireGroupMemberRecord(user, groupId);
    }

    private GroupMember requireGroupMemberRecord(AppUser user, Long groupId) {
        ageGateService.requireAdult(user);
        return groupMemberRepository.findByGroupIdAndUserId(groupId, user.getId())
                .orElseThrow(() -> new AccessDeniedException(
                        "Bu sohbet yalnızca grup üyelerine açıktır"
                ));
    }

    private void requireGroupAdmin(AppUser user, Long groupId) {
        GroupMember member = requireGroupMemberRecord(user, groupId);
        if (!isAdmin(member.getRole())) {
            throw new AccessDeniedException(
                    "Bu işlem için grup yöneticisi olmalısınız"
            );
        }
    }

    private boolean isAdmin(GroupRole role) {
        return role == GroupRole.FOUNDER
                || role == GroupRole.ADMIN
                || role == GroupRole.GROUP_ADMIN;
    }

    private void validateAttachment(MultipartFile file) {
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
        boolean image = isSafeImage(contentType);
        boolean pdf = contentType.equals(MediaType.APPLICATION_PDF_VALUE)
                || originalName.toLowerCase(Locale.ROOT).endsWith(".pdf");
        if (!image && !pdf) {
            throw new IllegalArgumentException("Yalnızca fotoğraf veya PDF yüklenebilir");
        }
    }

    private boolean isSafeImage(String contentType) {
        return contentType.equals(MediaType.IMAGE_JPEG_VALUE)
                || contentType.equals(MediaType.IMAGE_PNG_VALUE)
                || contentType.equals("image/webp");
    }
}
