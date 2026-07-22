package com.ecovision.backend.service;

import com.ecovision.backend.dto.CityLeaderboardEntry;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LeaderboardService {
    private final AppUserRepository userRepository;

    public LeaderboardService(AppUserRepository userRepository) {
        this.userRepository = userRepository;
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

    private String normalizeCity(String city) {
        return city == null || city.isBlank() ? AppUser.DEFAULT_CITY : city.trim();
    }
}
