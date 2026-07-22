package com.ecovision.backend.controller;

import com.ecovision.backend.dto.CarbonFootprintRequest;
import com.ecovision.backend.dto.GamificationResponse;
import com.ecovision.backend.dto.AvatarTierResponse;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.dto.RewardRedemptionRequest;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.GamificationService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import java.util.List;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/gamification")
public class GamificationController {
    private final GamificationService gamificationService;
    private final CurrentUserService currentUserService;

    public GamificationController(
            GamificationService gamificationService,
            CurrentUserService currentUserService
    ) {
        this.gamificationService = gamificationService;
        this.currentUserService = currentUserService;
    }

    @GetMapping
    public GamificationResponse state() {
        return gamificationService.state(currentUserService.currentUser());
    }

    @GetMapping("/avatar-tiers")
    public List<AvatarTierResponse> avatarTiers() {
        return gamificationService.avatarTiers(currentUserService.currentUser());
    }

    @PutMapping("/avatar/{level}/equip")
    public UserResponse equipAvatar(@PathVariable int level) {
        return gamificationService.equipAvatar(currentUserService.currentUser(), level);
    }

    @PostMapping("/carbon-footprint")
    public GamificationResponse completeCarbonFootprint(
            @Valid @RequestBody CarbonFootprintRequest request
    ) {
        return gamificationService.completeCarbonFootprint(
                currentUserService.currentUser(),
                request.score()
        );
    }

    @PostMapping("/redeem")
    public GamificationResponse redeem(
            @Valid @RequestBody RewardRedemptionRequest request
    ) {
        return gamificationService.redeem(
                currentUserService.currentUser(),
                request.rewardKey()
        );
    }
}
