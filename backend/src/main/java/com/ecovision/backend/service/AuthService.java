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
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.time.ZoneId;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCKOUT_DURATION = Duration.ofMinutes(15);
    private static final String DUMMY_PASSWORD_HASH =
            "$2a$10$7EqJtq98hPqEX7fNZaFWoO5c8jiKmP34AdVYI7Q7Dp4Qx5SIJdY8S";

    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final NotificationService notificationService;
    private final UsernameService usernameService;
    private final RefreshTokenService refreshTokenService;
    private final InputSanitizer inputSanitizer;
    private final GoogleTokenVerifierService googleTokenVerifierService;

    public AuthService(
            AppUserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            NotificationService notificationService,
            UsernameService usernameService,
            RefreshTokenService refreshTokenService,
            InputSanitizer inputSanitizer,
            GoogleTokenVerifierService googleTokenVerifierService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.notificationService = notificationService;
        this.usernameService = usernameService;
        this.refreshTokenService = refreshTokenService;
        this.inputSanitizer = inputSanitizer;
        this.googleTokenVerifierService = googleTokenVerifierService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.email().trim().toLowerCase();
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Bu e-posta adresi zaten kayıtlı");
        }
        validateAge(request.dateOfBirth());

        AppUser user = new AppUser();
        user.setName(inputSanitizer.plainText(request.name(), "Ad", 60));
        user.setSurname(inputSanitizer.plainText(request.surname(), "Soyad", 60));
        user.setEmail(email);
        user.setPublicUsername(usernameService.createUnique(request.username(), email));
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setDateOfBirth(request.dateOfBirth());
        user.setCity(normalizeCity(request.city()));
        user.setDistrict(inputSanitizer.plainText(request.district(), "İlçe", 60));
        user.setTermsAcceptedAt(Instant.now());
        user.setPrivacyAcceptedAt(Instant.now());
        user.setTotalPoints(0);
        user.setRole(Role.USER);
        user.setLastLoginDate(today());

        return response(userRepository.save(user));
    }

    @Transactional(noRollbackFor = {
            BadCredentialsException.class,
            LockedException.class
    })
    public AuthResponse login(LoginRequest request) {
        String email = request.email().trim().toLowerCase();
        AppUser user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            passwordEncoder.matches(request.password(), DUMMY_PASSWORD_HASH);
            throw new BadCredentialsException("E-posta veya parola hatalı");
        }
        if (user.getLockoutUntil() != null && user.getLockoutUntil().isAfter(Instant.now())) {
            throw new LockedException("Hesap geçici olarak kilitli");
        }
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            registerFailedAttempt(user);
            throw new BadCredentialsException("E-posta veya parola hatalı");
        }
        if (!user.isAccountNonLocked()) {
            throw new LockedException("Hesap kullanıma kapalı");
        }

        user.setFailedLoginAttempts(0);
        user.setLockoutUntil(null);
        user.setLastLoginDate(today());
        userRepository.save(user);
        notificationService.notifyStreakRisk(user);
        return response(user);
    }

    @Transactional
    public AuthResponse googleLogin(GoogleAuthRequest request) {
        GoogleTokenVerifierService.VerifiedGoogleIdentity identity =
                googleTokenVerifierService.verify(request.idToken());
        String email = identity.email();
        AppUser user = userRepository.findByEmail(email)
                .orElseGet(() -> {
                    AppUser newUser = new AppUser();
                    newUser.setEmail(email);
                    newUser.setPublicUsername(usernameService.createUnique(null, email));
                    newUser.setName(inputSanitizer.plainText(
                            defaultText(identity.givenName(), "Google"), "Ad", 60
                    ));
                    newUser.setSurname(inputSanitizer.plainText(
                            defaultText(identity.familyName(), "Kullanıcı"), "Soyad", 60
                    ));
                    newUser.setPassword(passwordEncoder.encode(
                            "GOOGLE:" + identity.subject()
                    ));
                    newUser.setProfilePictureUrl(identity.pictureUrl());
                    newUser.setDateOfBirth(today().minusYears(18));
                    newUser.setCity(AppUser.DEFAULT_CITY);
                    newUser.setTotalPoints(0);
                    newUser.setRole(Role.USER);
                    newUser.setLastLoginDate(today());
                    newUser.setTermsAcceptedAt(Instant.now());
                    newUser.setPrivacyAcceptedAt(Instant.now());
                    return userRepository.save(newUser);
                });

        if (!user.isAccountNonLocked()) {
            throw new LockedException("Hesap kullanıma kapalı");
        }
        if (identity.pictureUrl() != null && !identity.pictureUrl().isBlank()) {
            user.setProfilePictureUrl(identity.pictureUrl());
        }
        user.setLastLoginDate(today());
        userRepository.save(user);
        notificationService.notifyStreakRisk(user);
        return response(user);
    }

    @Transactional
    public AuthResponse refresh(String rawRefreshToken) {
        return response(refreshTokenService.consume(rawRefreshToken));
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }

    public void requestPasswordReset(String email) {
        userRepository.findByEmail(email.trim().toLowerCase()).ifPresent(user -> {
            // Deliberately return the same response whether the account exists or not.
        });
    }

    private AuthResponse response(AppUser user) {
        RefreshTokenService.IssuedRefreshToken refreshToken = refreshTokenService.issue(user);
        return new AuthResponse(
                jwtService.generateToken(user),
                refreshToken.value(),
                jwtService.getExpirationSeconds(),
                UserResponse.from(user)
        );
    }

    private void registerFailedAttempt(AppUser user) {
        int attempts = user.getFailedLoginAttempts() + 1;
        user.setFailedLoginAttempts(attempts);
        if (attempts >= MAX_FAILED_ATTEMPTS) {
            user.setLockoutUntil(Instant.now().plus(LOCKOUT_DURATION));
            user.setFailedLoginAttempts(0);
        }
        userRepository.saveAndFlush(user);
    }

    private void validateAge(LocalDate dateOfBirth) {
        LocalDate today = today();
        if (dateOfBirth == null
                || dateOfBirth.isAfter(today)
                || Period.between(dateOfBirth, today).getYears() < 13) {
            throw new IllegalArgumentException("EcoVision için en az 13 yaşında olmalısınız");
        }
    }

    private String normalizeCity(String city) {
        return city == null || city.isBlank()
                ? AppUser.DEFAULT_CITY
                : inputSanitizer.plainText(city, "İl", 60);
    }

    private String defaultText(String value, String fallback) {
        return value == null || value.isBlank()
                ? fallback
                : inputSanitizer.plainText(value, "Ad", 60);
    }

    private LocalDate today() {
        return LocalDate.now(ZoneId.of("Europe/Istanbul"));
    }
}
