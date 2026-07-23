package com.ecovision.backend.service;

import com.ecovision.backend.dto.GamificationResponse;
import com.ecovision.backend.dto.AvatarTierResponse;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import com.ecovision.backend.model.GamificationAction;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.GamificationActionRepository;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Arrays;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GamificationService {
    private static final String CARBON_MISSION_KEY = "mission_carbon_footprint";
    private static final int CARBON_MISSION_POINTS = 75;
    private static final Map<String, RewardDefinition> REWARD_CATALOG = rewardCatalog();

    private final AppUserRepository userRepository;
    private final GamificationActionRepository actionRepository;
    private final GroupActivityMessageService groupActivityMessages;

    public GamificationService(
            AppUserRepository userRepository,
            GamificationActionRepository actionRepository,
            GroupActivityMessageService groupActivityMessages
    ) {
        this.userRepository = userRepository;
        this.actionRepository = actionRepository;
        this.groupActivityMessages = groupActivityMessages;
    }

    @Transactional(readOnly = true)
    public GamificationResponse state(AppUser currentUser) {
        List<GamificationAction> actions = actionRepository
                .findByUserIdOrderByCreatedAtAsc(currentUser.getId());
        return response(currentUser, actions, 0, null, "Oyunlaştırma durumu yüklendi");
    }

    @Transactional(readOnly = true)
    public List<AvatarTierResponse> avatarTiers(AppUser user) {
        return Arrays.stream(AvatarTier.values())
                .map(tier -> AvatarTierResponse.from(
                        tier,
                        user.getLifetimePoints(),
                        user.getEquippedAvatarLevel()
                ))
                .toList();
    }

    @Transactional
    public UserResponse equipAvatar(AppUser currentUser, int level) {
        AvatarTier tier = AvatarTier.fromLevel(level);
        AppUser user = lockUser(currentUser.getId());
        if (user.getLifetimePoints() < tier.requiredLifetimePoints()) {
            throw new IllegalArgumentException("Bu avatar seviyesi henüz kilitli");
        }
        user.setEquippedAvatarLevel(level);
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public GamificationResponse completeCarbonFootprint(AppUser currentUser, int annualKg) {
        AppUser user = lockUser(currentUser.getId());
        if (actionRepository.existsByUserIdAndActionKey(user.getId(), CARBON_MISSION_KEY)) {
            return response(
                    user,
                    actions(user),
                    0,
                    "Karbon Bilinci",
                    "Karbon ayak izi ödülü daha önce alındı"
            );
        }

        AvatarTier previousTier = AvatarTier.highestUnlocked(user.getLifetimePoints());
        user.setTotalPoints(user.getTotalPoints() + CARBON_MISSION_POINTS);
        user.setLifetimePoints(user.getLifetimePoints() + CARBON_MISSION_POINTS);
        userRepository.save(user);
        saveAction(user, CARBON_MISSION_KEY, "MISSION", CARBON_MISSION_POINTS);
        AvatarTier currentTier = AvatarTier.highestUnlocked(user.getLifetimePoints());
        if (currentTier.level() > previousTier.level()) {
            groupActivityMessages.publishLevel(user, currentTier);
        }

        return response(
                user,
                actions(user),
                CARBON_MISSION_POINTS,
                "Karbon Bilinci",
                "Karbon ayak izi görevi yıllık " + annualKg
                        + " kg CO2e sonucuyla tamamlandı"
        );
    }

    @Transactional
    public GamificationResponse redeem(AppUser currentUser, String rewardKey) {
        RewardDefinition reward = REWARD_CATALOG.get(rewardKey);
        if (reward == null) {
            throw new IllegalArgumentException("Eco-Market ödülü bulunamadı");
        }

        AppUser user = lockUser(currentUser.getId());
        if (actionRepository.existsByUserIdAndActionKey(user.getId(), rewardKey)) {
            throw new IllegalArgumentException("Bu ödül zaten açıldı");
        }
        if (reward.requiredRewardKey() != null
                && !actionRepository.existsByUserIdAndActionKey(
                        user.getId(),
                        reward.requiredRewardKey()
                )) {
            throw new IllegalArgumentException("Önce bir önceki avatar seviyesini açın");
        }
        if (user.getTotalPoints() < reward.cost()) {
            throw new IllegalArgumentException("Bu ödül için daha fazla Eko Puan gerekiyor");
        }

        user.setTotalPoints(user.getTotalPoints() - reward.cost());
        userRepository.save(user);
        saveAction(user, rewardKey, reward.type(), -reward.cost());

        return response(
                user,
                actions(user),
                0,
                null,
                reward.title() + " açıldı"
        );
    }

    private AppUser lockUser(Long userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
    }

    private List<GamificationAction> actions(AppUser user) {
        return actionRepository.findByUserIdOrderByCreatedAtAsc(user.getId());
    }

    private void saveAction(
            AppUser user,
            String actionKey,
            String actionType,
            int pointsDelta
    ) {
        GamificationAction action = new GamificationAction();
        action.setUser(user);
        action.setActionKey(actionKey);
        action.setActionType(actionType);
        action.setPointsDelta(pointsDelta);
        actionRepository.save(action);
    }

    private GamificationResponse response(
            AppUser user,
            List<GamificationAction> actions,
            int pointsAwarded,
            String badge,
            String message
    ) {
        Set<String> actionKeys = actions.stream()
                .map(GamificationAction::getActionKey)
                .collect(LinkedHashSet::new, Set::add, Set::addAll);
        Set<String> redeemed = actionKeys.stream()
                .filter(REWARD_CATALOG::containsKey)
                .collect(LinkedHashSet::new, Set::add, Set::addAll);
        return new GamificationResponse(
                user.getTotalPoints(),
                actionKeys.contains(CARBON_MISSION_KEY),
                redeemed,
                pointsAwarded,
                badge,
                message
        );
    }

    private static Map<String, RewardDefinition> rewardCatalog() {
        Map<String, RewardDefinition> catalog = new LinkedHashMap<>();
        catalog.put(
                "avatar_eco_warrior",
                new RewardDefinition("Eko Savaşçı", 150, "AVATAR", null)
        );
        catalog.put(
                "avatar_planet_guardian",
                new RewardDefinition(
                        "Gezegen Muhafızı",
                        400,
                        "AVATAR",
                        "avatar_eco_warrior"
                )
        );
        catalog.put(
                "impact_coffee",
                new RewardDefinition("Ücretsiz Kahve", 300, "IMPACT", null)
        );
        catalog.put(
                "impact_tree",
                new RewardDefinition("Bir Ağaç Dik", 500, "IMPACT", null)
        );
        return Map.copyOf(catalog);
    }

    private record RewardDefinition(
            String title,
            int cost,
            String type,
            String requiredRewardKey
    ) {
    }
}
