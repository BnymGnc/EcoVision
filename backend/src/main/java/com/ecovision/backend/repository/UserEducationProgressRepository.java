package com.ecovision.backend.repository;

import com.ecovision.backend.model.UserEducationProgress;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserEducationProgressRepository
        extends JpaRepository<UserEducationProgress, Long> {
    boolean existsByUserIdAndCategoryId(Long userId, String categoryId);

    List<UserEducationProgress> findByUserIdOrderByCompletedAtAsc(Long userId);
}
