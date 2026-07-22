package com.ecovision.backend.service;

import com.ecovision.backend.dto.BadgeResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.BadgeType;
import com.ecovision.backend.model.UserBadge;
import com.ecovision.backend.model.NotificationType;
import com.ecovision.backend.repository.ProfileLikeRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import com.ecovision.backend.repository.UserBadgeRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BadgeService {
    private final UserBadgeRepository badgeRepository;
    private final ScanHistoryRepository scanRepository;
    private final ProfileLikeRepository likeRepository;
    private final NotificationService notifications;

    public BadgeService(UserBadgeRepository badgeRepository, ScanHistoryRepository scanRepository,
                        ProfileLikeRepository likeRepository, NotificationService notifications) {
        this.badgeRepository = badgeRepository;
        this.scanRepository = scanRepository;
        this.likeRepository = likeRepository;
        this.notifications = notifications;
    }

    @Transactional
    public void evaluateAfterScan(AppUser user) {
        if (user.getStreakCount() >= 7) award(user, BadgeType.STREAK_7);
        if (user.getStreakCount() >= 30) award(user, BadgeType.STREAK_30);
        if (scanRepository.countByUserIdAndMaterialTypeIgnoreCase(user.getId(), "Plastik Atık") >= 50)
            award(user, BadgeType.PLASTIC_HUNTER);
        if (scanRepository.countByUserIdAndMaterialTypeIgnoreCase(user.getId(), "Cam Atık") >= 50)
            award(user, BadgeType.GLASS_GUARDIAN);
    }

    @Transactional
    public void evaluateLikes(AppUser user) {
        if (likeRepository.countByLikedUserId(user.getId()) >= 50) award(user, BadgeType.PHENOMENON);
    }

    @Transactional(readOnly = true)
    public List<BadgeResponse> getBadges(Long userId) {
        return badgeRepository.findByUserIdOrderByAwardedAtAsc(userId).stream().map(BadgeResponse::from).toList();
    }

    private void award(AppUser user, BadgeType type) {
        if (badgeRepository.existsByUserIdAndBadgeType(user.getId(), type)) return;
        UserBadge badge = new UserBadge();
        badge.setUser(user);
        badge.setBadgeType(type);
        badgeRepository.save(badge);
        notifications.notifyUser(user, "Yeni rozet kazandın", "Tebrikler! " + type.title() + " rozeti artık senin.", NotificationType.GAMIFICATION);
    }
}
