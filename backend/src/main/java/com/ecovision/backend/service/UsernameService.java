package com.ecovision.backend.service;

import com.ecovision.backend.repository.AppUserRepository;
import java.util.Locale;
import org.springframework.stereotype.Service;

@Service
public class UsernameService {
    private static final int MAX_LENGTH = 30;
    private static final String USERNAME_PATTERN = "[a-z0-9_]{3,30}";

    private final AppUserRepository userRepository;

    public UsernameService(AppUserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public String createUnique(String requestedUsername, String email) {
        String base = requestedUsername == null || requestedUsername.isBlank()
                ? fromEmail(email)
                : normalizeAndValidate(requestedUsername);
        String candidate = base;
        int suffix = 2;
        while (userRepository.existsByPublicUsername(candidate)) {
            String suffixText = "_" + suffix++;
            candidate = base.substring(0, Math.min(base.length(), MAX_LENGTH - suffixText.length()))
                    + suffixText;
        }
        return candidate;
    }

    public String validateForUpdate(Long currentUserId, String requestedUsername) {
        String normalized = normalizeAndValidate(requestedUsername);
        userRepository.findByPublicUsername(normalized)
                .filter(user -> !user.getId().equals(currentUserId))
                .ifPresent(user -> {
                    throw new IllegalArgumentException("Bu kullanıcı adı zaten kullanılıyor");
                });
        return normalized;
    }

    private String normalizeAndValidate(String value) {
        String normalized = value.trim().toLowerCase(Locale.ROOT);
        if (!normalized.matches(USERNAME_PATTERN)) {
            throw new IllegalArgumentException(
                    "Kullanıcı adı 3-30 karakter olmalı ve yalnızca küçük harf, rakam veya alt çizgi içermelidir"
            );
        }
        return normalized;
    }

    private String fromEmail(String email) {
        String localPart = email == null ? "ecovision" : email.split("@", 2)[0];
        String sanitized = localPart.toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9_]", "");
        if (sanitized.length() < 3) {
            sanitized = "eco_" + sanitized;
        }
        return sanitized.substring(0, Math.min(sanitized.length(), MAX_LENGTH));
    }
}
