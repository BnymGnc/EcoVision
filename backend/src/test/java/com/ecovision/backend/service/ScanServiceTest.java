package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
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
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

@ExtendWith(MockitoExtension.class)
class ScanServiceTest {
    @Mock
    private ScanHistoryRepository scanHistoryRepository;

    @Mock
    private AppUserRepository userRepository;

    @Mock private ProfileLikeRepository profileLikeRepository;
    @Mock private UserBadgeRepository userBadgeRepository;
    @Mock private AppNotificationRepository notificationRepository;
    @Mock private ChatMessageRepository chatMessageRepository;
    @Mock private EventMemberRepository eventMemberRepository;
    @Mock private ApplicationEventPublisher applicationEventPublisher;

    private ScanService scanService;
    private AppUser user;

    @BeforeEach
    void setUp() {
        NotificationService notificationService = new NotificationService(notificationRepository, userRepository);
        GroupActivityMessageService groupActivityMessageService =
                new GroupActivityMessageService(eventMemberRepository, chatMessageRepository);
        BadgeService badgeService = new BadgeService(
                userBadgeRepository,
                scanHistoryRepository,
                profileLikeRepository,
                notificationService,
                groupActivityMessageService
        );
        scanService = new ScanService(
                scanHistoryRepository,
                userRepository,
                badgeService,
                groupActivityMessageService,
                new QuestEventPublisher(applicationEventPublisher)
        );
        user = new AppUser();
        user.setTotalPoints(0);
        user.setLifetimePoints(0);
        setUserId(user, 7L);
        when(userRepository.findByIdForUpdate(7L)).thenReturn(Optional.of(user));
    }

    @Test
    void awardsPointsFromServerCatalog() {
        when(scanHistoryRepository.save(any(ScanHistory.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ScanAnalysisResponse response = scanService.saveVerifiedAnalysis(
                user, "plastic waste", true, "a".repeat(64));

        assertEquals(10, response.pointsAwarded());
        assertEquals(10, response.updatedUserPoints());
        assertEquals(10, user.getLifetimePoints());
        assertEquals(1, user.getStreakCount());
    }

    private void setUserId(AppUser target, Long id) {
        target.setId(id);
    }

    @Test void labelOnlyCompatibilityCallNeverAwardsPoints() {
        when(scanHistoryRepository.save(any(ScanHistory.class))).thenAnswer(i -> i.getArgument(0));
        var result = scanService.analyzeAndSave(user, new ScanAnalysisRequest("plastic"));
        assertEquals(0,result.pointsAwarded());
        assertEquals(0,user.getTotalPoints());
        org.mockito.Mockito.verifyNoInteractions(applicationEventPublisher);
    }
    @Test void sameImageAndUncertainPredictionCannotAdvanceQuests() {
        when(scanHistoryRepository.save(any(ScanHistory.class))).thenAnswer(i -> i.getArgument(0));
        when(scanHistoryRepository.existsByUserIdAndImageHashAndRewardDateAndPointsAwardedGreaterThan(
            org.mockito.ArgumentMatchers.eq(7L),org.mockito.ArgumentMatchers.eq("b".repeat(64)),
            org.mockito.ArgumentMatchers.any(),org.mockito.ArgumentMatchers.eq(0))).thenReturn(true);
        var duplicate = scanService.saveVerifiedAnalysis(user,"plastic",true,"b".repeat(64));
        assertEquals(0,duplicate.pointsAwarded());
        assertEquals("DUPLICATE_IMAGE",duplicate.rewardStatus());
        var uncertain = scanService.saveVerifiedAnalysis(user,"plastic",false,"c".repeat(64));
        assertEquals(0,uncertain.pointsAwarded());
        org.mockito.Mockito.verifyNoInteractions(applicationEventPublisher);
    }
}
