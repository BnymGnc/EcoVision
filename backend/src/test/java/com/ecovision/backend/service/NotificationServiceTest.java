package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppNotification;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.NotificationType;
import com.ecovision.backend.repository.AppNotificationRepository;
import com.ecovision.backend.repository.AppUserRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {
    private static final ZoneId APP_ZONE = ZoneId.of("Europe/Istanbul");

    @Mock
    private AppNotificationRepository notificationRepository;

    @Mock
    private AppUserRepository userRepository;

    private NotificationService service;

    @BeforeEach
    void setUp() {
        service = new NotificationService(notificationRepository, userRepository);
    }

    @Test
    void broadcastCreatesOneSystemNotificationPerUser() {
        AppUser first = user(1L);
        AppUser second = user(2L);
        when(userRepository.findAll()).thenReturn(List.of(first, second));

        int recipients = service.broadcast("Yeni sürüm", "EcoVision V2 yayında.");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<AppNotification>> captor = ArgumentCaptor.forClass(List.class);
        verify(notificationRepository).saveAll(captor.capture());
        assertEquals(2, recipients);
        assertEquals(2, captor.getValue().size());
        assertEquals(NotificationType.SYSTEM, captor.getValue().get(0).getType());
    }

    @Test
    void streakWarningIsNotDuplicatedOnTheSameDay() {
        AppUser user = user(7L);
        user.setStreakCount(7);
        user.setLastScanDate(LocalDate.now(APP_ZONE).minusDays(1));
        when(notificationRepository.existsByUserIdAndTypeAndCreatedAtAfter(
                any(),
                any(),
                any()
        )).thenReturn(true);

        service.notifyStreakRisk(user);

        verify(notificationRepository, never()).save(any(AppNotification.class));
    }

    private AppUser user(Long id) {
        AppUser user = new AppUser();
        user.setId(id);
        return user;
    }
}
