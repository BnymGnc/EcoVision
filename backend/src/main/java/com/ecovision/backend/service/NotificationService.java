package com.ecovision.backend.service;

import com.ecovision.backend.dto.NotificationResponse;
import com.ecovision.backend.model.*;
import com.ecovision.backend.repository.AppNotificationRepository;
import com.ecovision.backend.repository.AppUserRepository;
import java.time.*;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {
    private static final ZoneId APP_ZONE = ZoneId.of("Europe/Istanbul");
    private final AppNotificationRepository notifications;
    private final AppUserRepository users;

    public NotificationService(AppNotificationRepository notifications, AppUserRepository users) {
        this.notifications = notifications; this.users = users;
    }

    @Transactional
    public void notifyUser(AppUser user, String title, String message, NotificationType type) {
        AppNotification notification = new AppNotification();
        notification.setUser(user); notification.setTitle(title); notification.setMessage(message); notification.setType(type);
        notifications.save(notification);
    }

    @Transactional
    public int broadcast(String title, String message) {
        List<AppNotification> batch = users.findAll().stream().map(user -> {
            AppNotification notification = new AppNotification(); notification.setUser(user);
            notification.setTitle(title); notification.setMessage(message); notification.setType(NotificationType.SYSTEM);
            return notification;
        }).toList();
        notifications.saveAll(batch); return batch.size();
    }

    @Transactional
    public void notifyCityEvent(Event event) {
        users.findByCityIgnoreCase(event.getCity()).stream()
                .filter(user -> !user.getId().equals(event.getCreator().getId()))
                .filter(AppUser::isAdult)
                .forEach(user -> notifyUser(user, "Şehrinde yeni bir temizlik grubu var",
                        event.getDistrict() + " bölgesinde " + event.getTitle() + " oluşturuldu.", NotificationType.LOCATION));
    }

    @Transactional
    public void notifyStreakRisk(AppUser user) {
        LocalDate today = LocalDate.now(APP_ZONE);
        if (user.getStreakCount() < 7 || user.getLastScanDate() == null || !user.getLastScanDate().equals(today.minusDays(1))) return;
        Instant startOfDay = today.atStartOfDay(APP_ZONE).toInstant();
        if (!notifications.existsByUserIdAndTypeAndCreatedAtAfter(user.getId(), NotificationType.STREAK, startOfDay)) {
            notifyUser(user, "Serini korumayı unutma", user.getStreakCount() + " günlük serin bugün tarama yapmazsan sona erecek.", NotificationType.STREAK);
        }
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> list(AppUser user, int limit) {
        int safeLimit = Math.min(Math.max(limit, 1), 100);
        return notifications.findByUserIdOrderByCreatedAtDesc(user.getId(), PageRequest.of(0, safeLimit)).stream().map(NotificationResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public long unreadCount(AppUser user) { return notifications.countByUserIdAndReadFalse(user.getId()); }

    @Transactional
    public int markAllRead(AppUser user) { return notifications.markAllRead(user.getId()); }
}
