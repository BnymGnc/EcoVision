package com.ecovision.backend.service;

import com.ecovision.backend.dto.GamificationResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.GamificationAction;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.GamificationActionRepository;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GamificationService {
    private static final String CARBON_MISSION_KEY = "mission_carbon_footprint";
    private static final int CARBON_MISSION_POINTS = 75;
    private static final Map<String, RewardDefinition> REWARD_CATALOG = rewardCatalog();

    private final AppUserRepository userRepository;
    private final GamificationActionRepository actionRepository;

    public GamificationService(
            AppUserRepository userRepository,
            GamificationActionRepository actionRepository
    ) {
        this.userRepository = userRepository;
        this.actionRepository = actionRepository;
    }

    @Transactional(readOnly = true)
    public GamificationResponse state(AppUser currentUser) {
        List<GamificationAction> actions = actionRepository
                .findByUserIdOrderByCreatedAtAsc(currentUser.getId());
        return response(currentUser, actions, 0, null, "Gamification state loaded");
    }

    @Transactional
    public GamificationResponse completeCarbonFootprint(AppUser currentUser, int score) {
        AppUser user = lockUser(currentUser.getId());
        if (actionRepository.existsByUserIdAndActionKey(user.getId(), CARBON_MISSION_KEY)) {
            return response(
                    user,
                    actions(user),
                    0,
                    "Carbon Conscious",
                    "Carbon footprint reward was already claimed"
            );
        }

        user.setTotalPoints(user.getTotalPoints() + CARBON_MISSION_POINTS);
        userRepository.save(user);
        saveAction(user, CARBON_MISSION_KEY, "MISSION", CARBON_MISSION_POINTS);

        return response(
                user,
                actions(user),
                CARBON_MISSION_POINTS,
                "Carbon Conscious",
                "Carbon footprint mission completed with score " + score
        );
    }

    @Transactional
    public GamificationResponse redeem(AppUser currentUser, String rewardKey) {
        RewardDefinition reward = REWARD_CATALOG.get(rewardKey);
        if (reward == null) {
            throw new IllegalArgumentException("Unknown Eco-Market reward");
        }

        AppUser user = lockUser(currentUser.getId());
        if (actionRepository.existsByUserIdAndActionKey(user.getId(), rewardKey)) {
            throw new IllegalArgumentException("This reward is already unlocked");
        }
        if (reward.requiredRewardKey() != null
                && !actionRepository.existsByUserIdAndActionKey(
                        user.getId(),
                        reward.requiredRewardKey()
                )) {
            throw new IllegalArgumentException("Unlock the previous avatar level first");
        }
        if (user.getTotalPoints() < reward.cost()) {
            throw new IllegalArgumentException("You need more Eco Points for this reward");
        }

        user.setTotalPoints(user.getTotalPoints() - reward.cost());
        userRepository.save(user);
        saveAction(user, rewardKey, reward.type(), -reward.cost());

        return response(
                user,
                actions(user),
                0,
                null,
                reward.title() + " unlocked"
        );
    }

    private AppUser lockUser(Long userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
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
                new RewardDefinition("Eco-Warrior", 150, "AVATAR", null)
        );
        catalog.put(
                "avatar_planet_guardian",
                new RewardDefinition(
                        "Planet Guardian",
                        400,
                        "AVATAR",
                        "avatar_eco_warrior"
                )
        );
        catalog.put(
                "impact_coffee",
                new RewardDefinition("Free Coffee", 300, "IMPACT", null)
        );
        catalog.put(
                "impact_tree",
                new RewardDefinition("Plant a Tree", 500, "IMPACT", null)
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
