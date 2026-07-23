package com.ecovision.backend.service;

import com.ecovision.backend.dto.CityLeaderboardEntry;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.FriendshipStatus;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.FriendshipRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LeaderboardService {
    private final AppUserRepository userRepository;
    private final FriendshipRepository friendshipRepository;

    public LeaderboardService(
            AppUserRepository userRepository,
            FriendshipRepository friendshipRepository
    ) {
        this.userRepository = userRepository;
        this.friendshipRepository = friendshipRepository;
    }

    @Transactional(readOnly = true)
    public List<CityLeaderboardEntry> cityLeaderboard(AppUser currentUser) {
        String city = normalizeCity(currentUser.getCity());
        List<AppUser> users = userRepository
                .findByCityIgnoreCaseOrderByTotalPointsDescNameAsc(city);
        List<CityLeaderboardEntry> entries = new ArrayList<>(users.size());
        for (int index = 0; index < users.size(); index++) {
            entries.add(CityLeaderboardEntry.from(
                    users.get(index),
                    index + 1,
                    currentUser.getId()
            ));
        }
        return entries;
    }

    @Transactional(readOnly = true)
    public List<CityLeaderboardEntry> friendsLeaderboard(AppUser currentUser) {
        Map<Long, AppUser> participants = new LinkedHashMap<>();
        participants.put(currentUser.getId(), currentUser);
        friendshipRepository.findForUser(
                currentUser.getId(),
                FriendshipStatus.ACCEPTED
        ).forEach(friendship -> {
            AppUser friend = friendship.getRequester().getId().equals(currentUser.getId())
                    ? friendship.getAddressee()
                    : friendship.getRequester();
            participants.put(friend.getId(), friend);
        });

        List<AppUser> ranked = participants.values().stream()
                .sorted(Comparator
                        .comparing(AppUser::getTotalPoints, Comparator.reverseOrder())
                        .thenComparing(
                                AppUser::getPublicUsername,
                                Comparator.nullsLast(Comparator.naturalOrder())
                        ))
                .toList();
        List<CityLeaderboardEntry> entries = new ArrayList<>(ranked.size());
        for (int index = 0; index < ranked.size(); index++) {
            entries.add(CityLeaderboardEntry.from(
                    ranked.get(index),
                    index + 1,
                    currentUser.getId()
            ));
        }
        return entries;
    }

    private String normalizeCity(String city) {
        return city == null || city.isBlank() ? AppUser.DEFAULT_CITY : city.trim();
    }
}
