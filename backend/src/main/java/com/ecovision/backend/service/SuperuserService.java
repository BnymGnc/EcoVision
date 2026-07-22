package com.ecovision.backend.service;

import com.ecovision.backend.dto.*;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.SocialReportRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SuperuserService {
    private final SocialReportRepository reports;
    private final ChatMessageRepository messages;
    private final AppUserRepository users;
    private final NotificationService notifications;
    private final EventService events;

    public SuperuserService(SocialReportRepository reports, ChatMessageRepository messages,
                            AppUserRepository users, NotificationService notifications, EventService events) {
        this.reports = reports; this.messages = messages; this.users = users; this.notifications = notifications; this.events = events;
    }

    @Transactional(readOnly = true)
    public List<ModerationReportResponse> reports() {
        return reports.findAllByOrderByCreatedAtDesc().stream().map(ModerationReportResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> auditGroup(Long groupId, int limit, int offset) {
        int safeLimit = Math.min(Math.max(limit, 1), 100); int safeOffset = Math.max(offset, 0);
        return messages.findByEventIdOrderByTimestampDesc(groupId, PageRequest.of(safeOffset / safeLimit, safeLimit))
                .stream().map(ChatMessageResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> auditUser(Long userId, int limit, int offset) {
        int safeLimit = Math.min(Math.max(limit, 1), 100); int safeOffset = Math.max(offset, 0);
        return messages.findBySenderIdOrderByTimestampDesc(userId, PageRequest.of(safeOffset / safeLimit, safeLimit))
                .stream().map(ChatMessageResponse::from).toList();
    }

    @Transactional
    public UserResponse ban(AppUser actor, Long userId) {
        AppUser user = manageableUser(actor, userId); user.setBanned(true); user.setSuspendedUntil(null);
        return UserResponse.from(users.save(user));
    }

    @Transactional
    public UserResponse unban(AppUser actor, Long userId) {
        AppUser user = manageableUser(actor, userId); user.setBanned(false); user.setSuspendedUntil(null);
        return UserResponse.from(users.save(user));
    }

    @Transactional
    public UserResponse suspend(AppUser actor, Long userId, int days) {
        AppUser user = manageableUser(actor, userId); user.setBanned(false);
        user.setSuspendedUntil(Instant.now().plus(days, ChronoUnit.DAYS));
        return UserResponse.from(users.save(user));
    }

    public int broadcast(BroadcastRequest request) { return notifications.broadcast(request.title().trim(), request.message().trim()); }
    public void deleteGroup(Long groupId) { events.deleteEventAsSuperuser(groupId); }

    private AppUser manageableUser(AppUser actor, Long userId) {
        if (actor.getId().equals(userId)) throw new IllegalArgumentException("Kendi hesabınız üzerinde moderasyon işlemi yapamazsınız");
        AppUser user = users.findByIdForUpdate(userId).orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        if (user.getRole().name().equals("SUPERUSER")) throw new IllegalArgumentException("Başka bir süper kullanıcı yönetilemez");
        return user;
    }
}
