package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;
import com.ecovision.backend.model.LoginDay;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.LoginDayRepository;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;

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

    @Test void monthHistoryReadsOnlyRequestedUsersCalendarAndDoesNotRecordNewActivity() {
        var users = mock(AppUserRepository.class);
        var days = mock(LoginDayRepository.class);
        var user = new AppUser(); user.setId(9L);
        when(days.findByUserIdAndLoginDateBetweenOrderByLoginDateAsc(9L,
                LocalDate.of(2024, 2, 1), LocalDate.of(2024, 2, 29)))
                .thenReturn(List.of(new LoginDay(user, LocalDate.of(2024, 2, 29))));
        var history = new LoginActivityService(users, days).history(9L, "2024-02");
        assertEquals("2024-02", history.month());
        assertEquals(List.of(LocalDate.of(2024, 2, 29)), history.loginDates());
        verifyNoInteractions(users);
        verify(days, never()).save(any());
    }

    @Test void malformedAndFutureMonthsAreRejectedBeforeDatabaseAccess() {
        var users = mock(AppUserRepository.class);
        var days = mock(LoginDayRepository.class);
        var service = new LoginActivityService(users, days);
        assertThrows(IllegalArgumentException.class, () -> service.history(1L, "2026-13"));
        assertThrows(IllegalArgumentException.class, () -> service.history(1L, "2026-1"));
        String future = YearMonth.now(ZoneId.of("Europe/Istanbul")).plusMonths(1).toString();
        assertThrows(IllegalArgumentException.class, () -> service.history(1L, future));
        verifyNoInteractions(users, days);
    }
}
