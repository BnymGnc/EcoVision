package com.ecovision.backend.controller;

import com.ecovision.backend.dto.CityLeaderboardEntry;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.LeaderboardService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/leaderboard")
public class LeaderboardController {
    private final LeaderboardService leaderboardService;
    private final CurrentUserService currentUserService;

    public LeaderboardController(
            LeaderboardService leaderboardService,
            CurrentUserService currentUserService
    ) {
        this.leaderboardService = leaderboardService;
        this.currentUserService = currentUserService;
    }

    @GetMapping("/city")
    public List<CityLeaderboardEntry> cityLeaderboard() {
        return leaderboardService.cityLeaderboard(currentUserService.currentUser());
    }

    @GetMapping("/friends")
    public List<CityLeaderboardEntry> friendsLeaderboard() {
        return leaderboardService.friendsLeaderboard(currentUserService.currentUser());
    }
}
