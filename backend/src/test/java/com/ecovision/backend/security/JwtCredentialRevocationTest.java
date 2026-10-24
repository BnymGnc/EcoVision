package com.ecovision.backend.security;

import static org.junit.jupiter.api.Assertions.*;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Role;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class JwtCredentialRevocationTest {
    @Test void passwordResetInvalidatesOnlyTargetsOldAccessToken() {
        var service = new JwtService("local-unit-test-only-signing-key-1234567890123456789", 900000);
        var target = user(1L, "admin@ecovision.invalid");
        var other = user(2L, "other@ecovision.invalid");
        String oldTargetToken = service.generateToken(target);
        String otherToken = service.generateToken(other);
        assertTrue(service.isValid(oldTargetToken, target));
        target.setCredentialsChangedAt(Instant.now());
        assertFalse(service.isValid(oldTargetToken, target));
        assertTrue(service.isValid(otherToken, other));
        assertTrue(service.isValid(service.generateToken(target), target));
    }
    private AppUser user(Long id, String email) {
        var user = new AppUser(); user.setId(id); user.setEmail(email); user.setRole(Role.USER);
        return user;
    }
}
