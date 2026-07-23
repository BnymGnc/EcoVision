package com.ecovision.backend.service;

import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.repository.AppUserRepository;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MarketService {
    private static final Map<String, Integer> CATALOG = Map.of(
            "leaf_frame", 100,
            "ocean_frame", 200,
            "earth_frame", 300,
            "streak_freeze", 250
    );

    private final AppUserRepository userRepository;
    private final QuestEventPublisher questEvents;

    public MarketService(
            AppUserRepository userRepository,
            QuestEventPublisher questEvents
    ) {
        this.userRepository = userRepository;
        this.questEvents = questEvents;
    }

    @Transactional
    public UserResponse purchase(AppUser currentUser, String itemId) {
        Integer price = CATALOG.get(itemId);
        if (price == null) {
            throw new IllegalArgumentException("Eco-Market ürünü bulunamadı");
        }

        AppUser user = userRepository.findByIdForUpdate(currentUser.getId())
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        boolean consumable = "streak_freeze".equals(itemId);
        if (!consumable && user.getOwnedMarketItems().contains(itemId)) {
            return UserResponse.from(user);
        }
        if (user.getTotalPoints() < price) {
            throw new IllegalArgumentException("Yeterli Eko Puanınız yok");
        }

        user.setTotalPoints(user.getTotalPoints() - price);
        if (consumable) {
            user.setStreakFreezeCount(user.getStreakFreezeCount() + 1);
        } else {
            user.getOwnedMarketItems().add(itemId);
        }
        AppUser saved = userRepository.save(user);
        questEvents.publish(
                saved.getId(),
                QuestTriggerType.BUY_MARKET_ITEM,
                price,
                Map.of(
                        "action", "market_purchase",
                        "itemId", itemId,
                        "itemType", itemType(itemId)
                )
        );
        return UserResponse.from(saved);
    }

    private String itemType(String itemId) {
        return itemId.endsWith("_frame") ? "avatar_frame" : "consumable";
    }
}
