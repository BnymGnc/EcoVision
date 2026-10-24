package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class LoginActivityServiceTest {
    @Test void sameDayNextDayAndMissedDayPreserveLongestStreak() {
        var user = new AppUser();
        var day = LocalDate.of(2026, 10, 24);
        LoginActivityService.applyDay(user, day);
        LoginActivityService.applyDay(user, day);
        assertEquals(1, user.getLoginStreakCount());
        LoginActivityService.applyDay(user, day.plusDays(1));
        assertEquals(2, user.getLoginStreakCount());
        LoginActivityService.applyDay(user, day.plusDays(3));
        assertEquals(1, user.getLoginStreakCount());
        assertEquals(2, user.getLongestLoginStreak());
    }
}
