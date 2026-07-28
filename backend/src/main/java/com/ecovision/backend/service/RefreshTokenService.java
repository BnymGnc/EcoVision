package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.RefreshToken;
import com.ecovision.backend.repository.RefreshTokenRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RefreshTokenService {
    private final RefreshTokenRepository repository;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Duration lifetime;

    public RefreshTokenService(
            RefreshTokenRepository repository,
            @Value("${app.jwt.refresh-expiration-ms}") long refreshExpirationMs
    ) {
        this.repository = repository;
        this.lifetime = Duration.ofMillis(refreshExpirationMs);
    }

    @Transactional
    public IssuedRefreshToken issue(AppUser user) {
        byte[] tokenBytes = new byte[64];
        secureRandom.nextBytes(tokenBytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes);
        Instant expiresAt = Instant.now().plus(lifetime);

        RefreshToken entity = new RefreshToken();
        entity.setUser(user);
        entity.setTokenHash(hash(rawToken));
        entity.setExpiresAt(expiresAt);
        repository.save(entity);
        return new IssuedRefreshToken(rawToken, expiresAt);
    }

    @Transactional
    public AppUser consume(String rawToken) {
        RefreshToken token = repository.findByTokenHashAndRevokedFalse(hash(rawToken))
                .orElseThrow(() -> new BadCredentialsException("Geçersiz oturum yenileme anahtarı"));
        token.setRevoked(true);
        repository.save(token);
        if (token.getExpiresAt().isBefore(Instant.now())
                || !token.getUser().isAccountNonLocked()
                || !token.getUser().isEnabled()) {
            throw new BadCredentialsException("Oturum yenileme anahtarının süresi doldu");
        }
        return token.getUser();
    }

    @Transactional
    public void revoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return;
        }
        repository.findByTokenHashAndRevokedFalse(hash(rawToken)).ifPresent(token -> {
            token.setRevoked(true);
            repository.save(token);
        });
    }

    private String hash(String value) {
        try {
            return java.util.HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256")
                            .digest(value.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 kullanılamıyor", exception);
        }
    }

    public record IssuedRefreshToken(String value, Instant expiresAt) {
    }
}
