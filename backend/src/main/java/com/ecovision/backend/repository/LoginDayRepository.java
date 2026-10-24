package com.ecovision.backend.repository;

import com.ecovision.backend.model.LoginDay;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoginDayRepository extends JpaRepository<LoginDay, Long> {
    boolean existsByUserIdAndLoginDate(Long userId, LocalDate date);
    List<LoginDay> findByUserIdAndLoginDateGreaterThanEqualOrderByLoginDateAsc(Long userId, LocalDate start);
}
