package com.ecovision.backend.service;

import com.ecovision.backend.dto.AuthResponse;
import com.ecovision.backend.dto.GoogleAuthRequest;
import com.ecovision.backend.dto.LoginRequest;
import com.ecovision.backend.dto.RegisterRequest;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.security.JwtService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    public AuthService(
            AppUserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            AuthenticationManager authenticationManager
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.authenticationManager = authenticationManager;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("Email is already registered");
        }

        AppUser user = new AppUser();
        user.setName(request.name());
        user.setSurname(request.surname());
        user.setEmail(request.email().trim().toLowerCase());
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setAge(request.age());
        user.setTotalPoints(0);
        user.setRole(Role.USER);

        AppUser saved = userRepository.save(user);
        return response(saved);
    }

    public AuthResponse login(LoginRequest request) {
        String email = request.email().trim().toLowerCase();
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(email, request.password())
        );
        AppUser user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        return response(user);
    }

    @Transactional
    public AuthResponse googleLogin(GoogleAuthRequest request) {
        AppUser user = userRepository.findByEmail(request.email().trim().toLowerCase())
                .orElseGet(() -> {
                    AppUser newUser = new AppUser();
                    newUser.setEmail(request.email().trim().toLowerCase());
                    newUser.setName(defaultText(request.name(), "Google"));
                    newUser.setSurname(defaultText(request.surname(), "User"));
                    newUser.setPassword(passwordEncoder.encode("GOOGLE:" + request.idToken().hashCode()));
                    newUser.setProfilePictureUrl(request.profilePictureUrl());
                    newUser.setTotalPoints(0);
                    newUser.setRole(Role.USER);
                    return userRepository.save(newUser);
                });

        if (request.profilePictureUrl() != null && !request.profilePictureUrl().isBlank()) {
            user.setProfilePictureUrl(request.profilePictureUrl());
        }

        return response(user);
    }

    private AuthResponse response(AppUser user) {
        return new AuthResponse(jwtService.generateToken(user), UserResponse.from(user));
    }

    private String defaultText(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }
}
