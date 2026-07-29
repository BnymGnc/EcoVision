package com.ecovision.backend.service;

import com.ecovision.backend.dto.EducationCompletionResponse;
import com.ecovision.backend.dto.GamificationResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.UserEducationProgress;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.UserEducationProgressRepository;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.IntStream;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EducationProgressService {
    private static final Set<String> SUPPORTED_CATEGORIES = IntStream
            .rangeClosed(1, 10)
            .mapToObj(index -> "modul-" + index)
            .collect(java.util.stream.Collectors.toUnmodifiableSet());

    private final AppUserRepository users;
    private final UserEducationProgressRepository progress;
    private final GamificationService gamification;

    public EducationProgressService(
            AppUserRepository users,
            UserEducationProgressRepository progress,
            GamificationService gamification
    ) {
        this.users = users;
        this.progress = progress;
        this.gamification = gamification;
    }

    @Transactional(readOnly = true)
    public List<String> completedCategoryIds(AppUser currentUser) {
        return progress.findByUserIdOrderByCompletedAtAsc(currentUser.getId())
                .stream()
                .map(UserEducationProgress::getCategoryId)
                .toList();
    }

    @Transactional
    public EducationCompletionResponse complete(
            AppUser currentUser,
            String rawCategoryId
    ) {
        String categoryId = normalizeAndValidate(rawCategoryId);
        AppUser user = users.findByIdForUpdate(currentUser.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Kullanıcı bulunamadı"
                ));

        if (progress.existsByUserIdAndCategoryId(user.getId(), categoryId)) {
            // Recover safely from an earlier request that persisted progress
            // but failed before the idempotent gamification action was saved.
            GamificationResponse reward = gamification.awardEducationModule(
                    user,
                    categoryId
            );
            return new EducationCompletionResponse(
                    categoryId,
                    false,
                    reward.pointsAwarded(),
                    reward.totalPoints(),
                    reward.pointsAwarded() > 0
                            ? "Eksik akademi ödülün hesabına eklendi"
                            : "Bu akademi modülü daha önce tamamlandı"
            );
        }

        UserEducationProgress completion = new UserEducationProgress();
        completion.setUser(user);
        completion.setCategoryId(categoryId);
        progress.save(completion);

        GamificationResponse reward = gamification.awardEducationModule(
                user,
                categoryId
        );
        return new EducationCompletionResponse(
                categoryId,
                true,
                reward.pointsAwarded(),
                reward.totalPoints(),
                reward.message()
        );
    }

    private String normalizeAndValidate(String rawCategoryId) {
        String categoryId = rawCategoryId == null
                ? ""
                : rawCategoryId.trim().toLowerCase(Locale.ROOT);
        if (!SUPPORTED_CATEGORIES.contains(categoryId)) {
            throw new IllegalArgumentException("Geçersiz akademi modülü");
        }
        return categoryId;
    }
}
