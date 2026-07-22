package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.dto.ScanAnalysisRequest;
import com.ecovision.backend.dto.ScanAnalysisResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ScanHistory;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import com.ecovision.backend.repository.ProfileLikeRepository;
import com.ecovision.backend.repository.UserBadgeRepository;
import com.ecovision.backend.repository.AppNotificationRepository;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ScanServiceTest {
    @Mock
    private ScanHistoryRepository scanHistoryRepository;

    @Mock
    private AppUserRepository userRepository;

    @Mock private ProfileLikeRepository profileLikeRepository;
    @Mock private UserBadgeRepository userBadgeRepository;
    @Mock private AppNotificationRepository notificationRepository;

    private ScanService scanService;
    private AppUser user;

    @BeforeEach
    void setUp() {
        NotificationService notificationService = new NotificationService(notificationRepository, userRepository);
        BadgeService badgeService = new BadgeService(userBadgeRepository, scanHistoryRepository, profileLikeRepository, notificationService);
        scanService = new ScanService(scanHistoryRepository, userRepository, badgeService);
        user = new AppUser();
        user.setTotalPoints(0);
        user.setLifetimePoints(0);
        setUserId(user, 7L);
        when(userRepository.findByIdForUpdate(7L)).thenReturn(Optional.of(user));
    }

    @Test
    void awardsPointsFromServerCatalog() {
        when(scanHistoryRepository.countByUserIdAndScannedAtAfter(any(), any()))
                .thenReturn(0L);
        when(scanHistoryRepository.save(any(ScanHistory.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ScanAnalysisResponse response = scanService.analyzeAndSave(
                user,
                new ScanAnalysisRequest("plastic waste")
        );

        assertEquals(10, response.pointsAwarded());
        assertEquals(10, response.updatedUserPoints());
        assertEquals(10, user.getLifetimePoints());
        assertEquals(1, user.getStreakCount());
    }

    @Test
    void blocksFourthScanInsideCooldownWindow() {
        ScanHistory oldest = new ScanHistory();
        oldest.setScannedAt(Instant.now().minusSeconds(60));
        when(scanHistoryRepository.countByUserIdAndScannedAtAfter(any(), any()))
                .thenReturn(3L);
        when(scanHistoryRepository.findFirstByUserIdAndScannedAtAfterOrderByScannedAtAsc(
                any(),
                any()
        )).thenReturn(Optional.of(oldest));

        assertThrows(
                ScanCooldownException.class,
                () -> scanService.analyzeAndSave(user, new ScanAnalysisRequest("glass"))
        );
        verify(scanHistoryRepository, never()).save(any());
    }

    private void setUserId(AppUser target, Long id) {
        target.setId(id);
    }
}
