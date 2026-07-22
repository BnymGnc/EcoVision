package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ChangePasswordRequest;
import com.ecovision.backend.dto.UpdateProfileRequest;
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
    private final ProfileService profileService;
    private final CurrentUserService currentUserService;

    public UserController(
            ProfileService profileService,
            CurrentUserService currentUserService
    ) {
        this.profileService = profileService;
        this.currentUserService = currentUserService;
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
}
