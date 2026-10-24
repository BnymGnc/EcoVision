package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.LoginDay;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.LoginDayRepository;
import java.time.*;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LoginActivityService {
    private final AppUserRepository users;
    private final LoginDayRepository days;
    public LoginActivityService(AppUserRepository users, LoginDayRepository days) { this.users = users; this.days = days; }

    @Transactional
    public Status record(Long userId) {
        AppUser user = users.findByIdForUpdate(userId).orElseThrow();
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Istanbul"));
        applyDay(user, today);
        if (!days.existsByUserIdAndLoginDate(userId, today)) days.save(new LoginDay(user, today));
        users.save(user);
        return new Status(user.getLoginStreakCount(), user.getLongestLoginStreak(), today,
                days.findByUserIdAndLoginDateGreaterThanEqualOrderByLoginDateAsc(userId, today.minusDays(6))
                        .stream().map(LoginDay::getLoginDate).toList());
    }

    public static void applyDay(AppUser user, LocalDate today) {
        if (!today.equals(user.getLastLoginDate())) {
            user.setLoginStreakCount(today.minusDays(1).equals(user.getLastLoginDate())
                    ? user.getLoginStreakCount() + 1 : 1);
            user.setLastLoginDate(today);
        }
        user.setLongestLoginStreak(Math.max(user.getLongestLoginStreak(), user.getLoginStreakCount()));
    }
    @Transactional(readOnly = true)
    public History history(Long userId, String month) {
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Istanbul"));
        YearMonth selected = YearMonth.from(today);
        if (month != null && !month.isBlank()) {
            try {
                if (!month.matches("[0-9]{4}-(0[1-9]|1[0-2])")) throw new DateTimeException("Invalid month");
                selected = YearMonth.parse(month);
            } catch (DateTimeException failure) {
                throw new IllegalArgumentException("Ay bilgisi YYYY-AA biçiminde olmalıdır");
            }
        }
        if (selected.getYear() < 1 || selected.isAfter(YearMonth.from(today)))
            throw new IllegalArgumentException("Gelecek ayın giriş kayıtları görüntülenemez");
        LocalDate end = selected.atEndOfMonth().isAfter(today) ? today : selected.atEndOfMonth();
        return new History(selected.toString(), today,
                days.findByUserIdAndLoginDateBetweenOrderByLoginDateAsc(userId,
                        selected.atDay(1), end).stream().map(LoginDay::getLoginDate).toList());
    }
    public record History(String month, LocalDate today, List<LocalDate> loginDates) {}
    public record Status(int currentStreak, int longestStreak, LocalDate today, List<LocalDate> lastSevenDays) {}
}
