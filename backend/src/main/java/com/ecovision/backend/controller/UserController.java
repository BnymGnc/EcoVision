package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ChangePasswordRequest;
import com.ecovision.backend.dto.UpdateProfileRequest;
import com.ecovision.backend.dto.ProfileVisibilityRequest;
import com.ecovision.backend.dto.ThemePreferenceRequest;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.ProfileService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final com.ecovision.backend.service.LoginActivityService loginActivity;
    private final ProfileService profileService;
    private final CurrentUserService currentUserService;

    public UserController(
            ProfileService profileService,
            com.ecovision.backend.service.LoginActivityService loginActivity,
            CurrentUserService currentUserService
    ) {
        this.profileService = profileService;
        this.loginActivity = loginActivity;
        this.currentUserService = currentUserService;
    }

    @org.springframework.web.bind.annotation.GetMapping("/login-streak")
    public com.ecovision.backend.service.LoginActivityService.Status loginStreak() {
        return loginActivity.record(currentUserService.currentUser().getId());
    }

    @PutMapping("/profile")
    public UserResponse updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return profileService.updateProfile(currentUserService.currentUser(), request);
    }

    @PutMapping("/password")
    public Map<String, String> changePassword(
            @Valid @RequestBody ChangePasswordRequest request
    ) {
        profileService.changePassword(currentUserService.currentUser(), request);
        return Map.of("message", "Password updated successfully");
    }

    @PutMapping("/privacy")
    public UserResponse updateVisibility(
            @Valid @RequestBody ProfileVisibilityRequest request
    ) {
        return profileService.updateVisibility(currentUserService.currentUser(), request);
    }

    @PutMapping("/theme")
    public UserResponse updateTheme(
            @Valid @RequestBody ThemePreferenceRequest request
    ) {
        return profileService.updateTheme(
                currentUserService.currentUser(),
                request
        );
    }
}
