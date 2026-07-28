package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.ecovision.backend.model.AppUser;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

class AgeGateServiceTest {
    private final AgeGateService ageGate = new AgeGateService();

    @Test
    void rejectsUsersUnderEighteen() {
        AppUser user = new AppUser();
        user.setAge(17);
        assertThrows(AccessDeniedException.class, () -> ageGate.requireAdult(user));
    }

    @Test
    void allowsAdults() {
        AppUser user = new AppUser();
        user.setAge(18);
        assertDoesNotThrow(() -> ageGate.requireAdult(user));
    }

    @Test
    void calculatesAdultStatusFromDateOfBirth() {
        AppUser user = new AppUser();
        user.setAge(null);
        user.setDateOfBirth(LocalDate.now().minusYears(18));
        assertDoesNotThrow(() -> ageGate.requireAdult(user));
    }
}
