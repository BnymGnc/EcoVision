package com.ecovision.backend.service;

import com.ecovision.backend.dto.ScanAnalysisRequest;
import com.ecovision.backend.dto.ScanAnalysisResponse;
import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ScanHistory;
import com.ecovision.backend.model.WasteMaterial;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import java.util.List;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScanService {
    private static final int SCAN_LIMIT = 3;
    private static final Duration SCAN_WINDOW = Duration.ofMinutes(15);

    private final ScanHistoryRepository scanHistoryRepository;
    private final AppUserRepository userRepository;
    private final BadgeService badgeService;

    public ScanService(
            ScanHistoryRepository scanHistoryRepository,
            AppUserRepository userRepository,
            BadgeService badgeService
    ) {
        this.scanHistoryRepository = scanHistoryRepository;
        this.userRepository = userRepository;
        this.badgeService = badgeService;
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

    private ScanHistory analyzeAndPersist(Long userId, String detectedClass) {
        AppUser user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        Instant now = Instant.now();
        Instant windowStart = now.minus(SCAN_WINDOW);
        long recentScans = scanHistoryRepository.countByUserIdAndScannedAtAfter(userId, windowStart);
        if (recentScans >= SCAN_LIMIT) {
            Instant oldest = scanHistoryRepository
                    .findFirstByUserIdAndScannedAtAfterOrderByScannedAtAsc(userId, windowStart)
                    .map(ScanHistory::getScannedAt)
                    .orElse(now);
            long retryAfter = Duration.between(now, oldest.plus(SCAN_WINDOW)).toSeconds();
            throw new ScanCooldownException(retryAfter);
        }

        String prediction = detectedClass == null ? "" : detectedClass.trim();
        WasteMaterial material = WasteMaterial.detect(prediction);
        int points = material.points();

        ScanHistory scan = new ScanHistory();
        scan.setUser(user);
        scan.setMaterialType(material.displayName());
        scan.setIsRecyclable(material.recyclable());
        scan.setDecayYears(material.decayYears());
        scan.setRecycledInto(material.recycledInto());
        scan.setPointsAwarded(points);
        scan.setScannedAt(now);

        user.setTotalPoints(user.getTotalPoints() + points);
        user.setLifetimePoints(user.getLifetimePoints() + points);
        updateStreak(user);
        userRepository.save(user);
        ScanHistory saved = scanHistoryRepository.save(scan);
        scanHistoryRepository.flush();
        badgeService.evaluateAfterScan(user);
        return saved;
    }

    private void updateStreak(AppUser user) {
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Istanbul"));
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
