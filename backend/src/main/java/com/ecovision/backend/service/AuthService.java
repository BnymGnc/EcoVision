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
import java.time.LocalDate;
import java.time.ZoneId;

@Service
public class AuthService {
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final NotificationService notificationService;
    private final UsernameService usernameService;

    public AuthService(
            AppUserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            AuthenticationManager authenticationManager,
            NotificationService notificationService,
            UsernameService usernameService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.authenticationManager = authenticationManager;
        this.notificationService = notificationService;
        this.usernameService = usernameService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("Bu e-posta adresi zaten kayıtlı");
        }

        AppUser user = new AppUser();
        user.setName(request.name());
        user.setSurname(request.surname());
        user.setEmail(request.email().trim().toLowerCase());
        user.setPublicUsername(usernameService.createUnique(request.username(), user.getEmail()));
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setAge(request.age());
        user.setCity(normalizeCity(request.city()));
        user.setTotalPoints(0);
        user.setRole(Role.USER);
        user.setLastLoginDate(today());

        AppUser saved = userRepository.save(user);
        return response(saved);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String email = request.email().trim().toLowerCase();
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(email, request.password())
        );
        AppUser user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        user.setLastLoginDate(today());
        userRepository.save(user);
        notificationService.notifyStreakRisk(user);
        return response(user);
    }

    @Transactional
    public AuthResponse googleLogin(GoogleAuthRequest request) {
        AppUser user = userRepository.findByEmail(request.email().trim().toLowerCase())
                .orElseGet(() -> {
                    AppUser newUser = new AppUser();
                    newUser.setEmail(request.email().trim().toLowerCase());
                    newUser.setPublicUsername(usernameService.createUnique(null, newUser.getEmail()));
                    newUser.setName(defaultText(request.name(), "Google"));
                    newUser.setSurname(defaultText(request.surname(), "Kullanıcı"));
                    newUser.setPassword(passwordEncoder.encode("GOOGLE:" + request.idToken().hashCode()));
                    newUser.setProfilePictureUrl(request.profilePictureUrl());
                    newUser.setCity(AppUser.DEFAULT_CITY);
                    newUser.setTotalPoints(0);
                    newUser.setRole(Role.USER);
                    newUser.setLastLoginDate(today());
                    return userRepository.save(newUser);
                });

        if (request.profilePictureUrl() != null && !request.profilePictureUrl().isBlank()) {
            user.setProfilePictureUrl(request.profilePictureUrl());
        }

        user.setLastLoginDate(today());
        userRepository.save(user);
        notificationService.notifyStreakRisk(user);
        return response(user);
    }

    private AuthResponse response(AppUser user) {
        return new AuthResponse(jwtService.generateToken(user), UserResponse.from(user));
    }

    private String defaultText(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private String normalizeCity(String city) {
        return city == null || city.isBlank() ? AppUser.DEFAULT_CITY : city.trim();
    }

    private LocalDate today() {
        return LocalDate.now(ZoneId.of("Europe/Istanbul"));
    }
}
