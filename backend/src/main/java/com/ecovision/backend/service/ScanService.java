package com.ecovision.backend.service;

import com.ecovision.backend.dto.ScanAnalysisRequest;
import com.ecovision.backend.dto.ScanAnalysisResponse;
import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.ScanHistory;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.model.WasteMaterial;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import java.util.List;
import java.util.Map;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScanService {
    private final ScanHistoryRepository scanHistoryRepository;
    private final AppUserRepository userRepository;
    private final BadgeService badgeService;
    private final GroupActivityMessageService groupActivityMessages;
    private final QuestEventPublisher questEvents;

    public ScanService(
            ScanHistoryRepository scanHistoryRepository,
            AppUserRepository userRepository,
            BadgeService badgeService,
            GroupActivityMessageService groupActivityMessages,
            QuestEventPublisher questEvents
    ) {
        this.scanHistoryRepository = scanHistoryRepository;
        this.userRepository = userRepository;
        this.badgeService = badgeService;
        this.groupActivityMessages = groupActivityMessages;
        this.questEvents = questEvents;
    }

    public List<ScanResponse> getScans(AppUser user) {
        return scanHistoryRepository.findByUserIdOrderByScannedAtDesc(user.getId())
                .stream()
                .map(ScanResponse::from)
                .toList();
    }

    @Transactional
    public ScanResponse saveScan(AppUser user, ScanRequest request) {
        return ScanResponse.from(analyzeAndPersist(user.getId(), request.materialType()));
    }

    @Transactional
    public ScanAnalysisResponse analyzeAndSave(AppUser user, ScanAnalysisRequest request) {
        return ScanAnalysisResponse.from(analyzeAndPersist(user.getId(), request.detectedClass()));
    }

    @Transactional
    public ScanAnalysisResponse analyzeAndSave(AppUser user, ScanAnalysisRequest request, boolean acceptedPrediction) {
        return ScanAnalysisResponse.from(analyzeAndPersist(user.getId(), request.detectedClass(), acceptedPrediction));
    }

    private ScanHistory analyzeAndPersist(Long userId, String detectedClass) {
        return analyzeAndPersist(userId, detectedClass, false);
    }

    private ScanHistory analyzeAndPersist(Long userId, String detectedClass, boolean acceptedPrediction) {
        // Label-only compatibility calls can log history but never mint XP.
        return analyzeAndPersist(userId, detectedClass, false, null);
    }

    @Transactional
    public ScanAnalysisResponse saveVerifiedAnalysis(AppUser user, String detectedClass,
            boolean acceptedPrediction, String imageHash) {
        if (imageHash == null || !imageHash.matches("[a-f0-9]{64}")) throw new IllegalArgumentException("Geçersiz analiz kimliği");
        return ScanAnalysisResponse.from(analyzeAndPersist(user.getId(), detectedClass, acceptedPrediction, imageHash));
    }

    private ScanHistory analyzeAndPersist(Long userId, String detectedClass, boolean acceptedPrediction, String imageHash) {
        AppUser user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        Instant now = Instant.now();

        String prediction = detectedClass == null ? "" : detectedClass.trim();
        WasteMaterial material = WasteMaterial.detect(prediction);
        LocalDate rewardDate = now.atZone(ZoneId.of("Europe/Istanbul")).toLocalDate();
        boolean duplicate = imageHash != null && scanHistoryRepository
            .existsByUserIdAndImageHashAndPointsAwardedGreaterThan(userId, imageHash, 0);
        int points = acceptedPrediction && !duplicate ? material.points() : 0;
        AvatarTier previousTier = AvatarTier.highestUnlocked(user.getLifetimePoints());

        ScanHistory scan = new ScanHistory();
        scan.setAnalysisId(imageHash == null ? null : java.util.UUID.randomUUID());
        scan.setImageHash(imageHash);
        scan.setRewardDate(imageHash == null ? null : rewardDate);
        scan.setRewardStatus(duplicate ? "DUPLICATE_IMAGE" : points > 0 ? "AWARDED" : "NO_REWARD");
        scan.setUser(user);
        scan.setMaterialType(material.displayName());
        scan.setIsRecyclable(material.recyclable());
        scan.setDecayYears(material.decayYears());
        scan.setRecycledInto(material.recycledInto());
        scan.setPointsAwarded(points);
        scan.setScannedAt(now);

        user.setTotalPoints(user.getTotalPoints() + points);
        user.setLifetimePoints(user.getLifetimePoints() + points);
        if (points > 0) updateStreak(user, rewardDate);
        userRepository.save(user);
        ScanHistory saved = scanHistoryRepository.save(scan);
        scanHistoryRepository.flush();
        if (points > 0) badgeService.evaluateAfterScan(user);
        AvatarTier currentTier = AvatarTier.highestUnlocked(user.getLifetimePoints());
        if (currentTier.level() > previousTier.level()) {
            groupActivityMessages.publishLevel(user, currentTier);
        }
        if (points > 0) publishQuestEvents(user, material);
        return saved;
    }

    private void publishQuestEvents(AppUser user, WasteMaterial material) {
        Map<String, Object> scanAttributes = Map.of(
                "action", "scan",
                "wasteType", material.name().toLowerCase(),
                "wasteCategory", material.name().toLowerCase()
        );
        questEvents.publish(
                user.getId(),
                QuestTriggerType.SCAN_SPECIFIC_WASTE,
                1,
                scanAttributes
        );
        questEvents.publish(
                user.getId(),
                QuestTriggerType.TIME_BASED,
                1,
                scanAttributes
        );
        questEvents.publish(
                user.getId(),
                QuestTriggerType.STREAK_DAYS,
                user.getStreakCount(),
                Map.of(
                        "metric", "streak_days",
                        "value", user.getStreakCount()
                )
        );
        questEvents.publish(
                user.getId(),
                QuestTriggerType.REACH_SCORE,
                user.getTotalPoints(),
                Map.of(
                        "metric", "total_points",
                        "value", user.getTotalPoints()
                )
        );
    }

    private void updateStreak(AppUser user, LocalDate today) {
        LocalDate last = user.getLastScanDate();
        if (today.equals(last)) return;
        if (last != null && last.equals(today.minusDays(1))) {
            user.setStreakCount(user.getStreakCount() + 1);
        } else if (last != null && last.equals(today.minusDays(2)) && user.getStreakFreezeCount() > 0) {
            user.setStreakFreezeCount(user.getStreakFreezeCount() - 1);
            user.setStreakCount(user.getStreakCount() + 1);
        } else {
            user.setStreakCount(1);
        }
        user.setLastScanDate(today);
    }
}
