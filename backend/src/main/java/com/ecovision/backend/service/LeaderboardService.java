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
import org.springframework.data.domain.PageRequest;

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
    public LeaderboardPage globalLeaderboard(AppUser currentUser, String city, int page, int size) {
        if (page < 0 || page > 100000 || size < 1 || size > 100
                || (city != null && city.length() > 80)) {
            throw new IllegalArgumentException("Geçersiz sıralama filtresi");
        }
        // A bound null can be inferred as bytea by PostgreSQL inside lower().
        String filter = city == null ? "" : city.trim();
        var users = userRepository.findRankedUsers(filter, PageRequest.of(page, size));
        var friendIds = friendshipRepository.findForUser(currentUser.getId(), FriendshipStatus.ACCEPTED)
                .stream().map(friendship -> friendship.getRequester().getId().equals(currentUser.getId())
                        ? friendship.getAddressee().getId() : friendship.getRequester().getId())
                .collect(java.util.stream.Collectors.toSet());
        List<CityLeaderboardEntry> entries = new ArrayList<>(users.getNumberOfElements());
        int offset = page * size;
        for (int index = 0; index < users.getContent().size(); index++) {
            var user = users.getContent().get(index);
            entries.add(CityLeaderboardEntry.from(user, offset + index + 1,
                    currentUser.getId(), friendIds.contains(user.getId())));
        }
        return new LeaderboardPage(entries, users.hasNext(), users.getTotalElements());
    }

    public record LeaderboardPage(List<CityLeaderboardEntry> items, boolean hasMore, long total) {}

    @Transactional(readOnly = true)
    public List<CityLeaderboardEntry> cityLeaderboard(AppUser currentUser) {
        String city = normalizeCity(currentUser.getCity());
        List<AppUser> users = userRepository
                .findByCityIgnoreCaseOrderByTotalPointsDescNameAsc(city);
        var acceptedFriendIds = friendshipRepository.findForUser(
                currentUser.getId(),
                FriendshipStatus.ACCEPTED
        ).stream().map(friendship ->
                friendship.getRequester().getId().equals(currentUser.getId())
                        ? friendship.getAddressee().getId()
                        : friendship.getRequester().getId()
        ).collect(java.util.stream.Collectors.toSet());
        List<CityLeaderboardEntry> entries = new ArrayList<>(users.size());
        for (int index = 0; index < users.size(); index++) {
            entries.add(CityLeaderboardEntry.from(
                    users.get(index),
                    index + 1,
                    currentUser.getId(),
                    acceptedFriendIds.contains(users.get(index).getId())
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
                    currentUser.getId(),
                    !ranked.get(index).getId().equals(currentUser.getId())
            ));
        }
        return entries;
    }

    private String normalizeCity(String city) {
        return city == null ? "" : city.trim();
    }
}
