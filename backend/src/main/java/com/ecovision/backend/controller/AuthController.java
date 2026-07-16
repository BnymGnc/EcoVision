package com.ecovision.backend.controller;

import com.ecovision.backend.dto.AuthResponse;
import com.ecovision.backend.dto.GoogleAuthRequest;
import com.ecovision.backend.dto.LoginRequest;
import com.ecovision.backend.dto.RegisterRequest;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.service.AuthService;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;
    private final CurrentUserService currentUserService;
    private final ProfileService profileService;

    public AuthController(
            AuthService authService,
            CurrentUserService currentUserService,
            ProfileService profileService
    ) {
        this.authService = authService;
        this.currentUserService = currentUserService;
        this.profileService = profileService;
    }

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/google")
    public AuthResponse google(@Valid @RequestBody GoogleAuthRequest request) {
        return authService.googleLogin(request);
    }

    @GetMapping("/me")
    public UserResponse me() {
        return UserResponse.from(currentUserService.currentUser());
    }

    @PostMapping(
            value = "/me/profile-picture",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public UserResponse uploadProfilePicture(@RequestParam("image") MultipartFile image) {
        return profileService.updateProfilePicture(currentUserService.currentUser(), image);
    }
}
