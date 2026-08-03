package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.dto.EducationCompletionResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.GamificationActionRepository;
import com.ecovision.backend.repository.UserEducationProgressRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class EducationProgressServiceTest {
    @Mock private AppUserRepository users;
    @Mock private UserEducationProgressRepository progress;
    @Mock private GamificationActionRepository actions;

    private EducationProgressService service;
    private AppUser user;

    @BeforeEach
    void setUp() {
        GamificationService gamification = new GamificationService(
                users,
                actions,
                null,
                null
        );
        service = new EducationProgressService(users, progress, gamification);
        user = new AppUser();
        user.setId(7L);
        user.setTotalPoints(10);
        user.setLifetimePoints(10);
    }

    @Test
    void firstCompletionPersistsProgressAndAwardsPoints() {
        when(users.findByIdForUpdate(7L)).thenReturn(Optional.of(user));
        when(progress.existsByUserIdAndCategoryId(7L, "modul-1"))
                .thenReturn(false);
        when(actions.existsByUserIdAndActionKey(7L, "education_modul-1"))
                .thenReturn(false);
        when(actions.findByUserIdOrderByCreatedAtAsc(7L))
                .thenReturn(List.of());

        EducationCompletionResponse response =
                service.complete(user, "MODUL-1");

        assertTrue(response.newlyCompleted());
        assertEquals(30, response.pointsAwarded());
        assertEquals(40, response.totalPoints());
        assertEquals(40, user.getLifetimePoints());
        verify(progress).save(any());
        verify(actions).save(any());
    }

    @Test
    void repeatedCompletionDoesNotAwardPointsAgain() {
        when(users.findByIdForUpdate(7L)).thenReturn(Optional.of(user));
        when(progress.existsByUserIdAndCategoryId(7L, "modul-1"))
                .thenReturn(true);
        when(actions.existsByUserIdAndActionKey(7L, "education_modul-1"))
                .thenReturn(true);
        when(actions.findByUserIdOrderByCreatedAtAsc(7L))
                .thenReturn(List.of());

        EducationCompletionResponse response =
                service.complete(user, "modul-1");

        assertFalse(response.newlyCompleted());
        assertEquals(0, response.pointsAwarded());
        assertEquals(10, response.totalPoints());
        verify(progress, never()).save(any());
        verify(actions, never()).save(any());
    }

    @Test
    void existingProgressRecoversMissingOneTimeReward() {
        when(users.findByIdForUpdate(7L)).thenReturn(Optional.of(user));
        when(progress.existsByUserIdAndCategoryId(7L, "modul-1"))
                .thenReturn(true);
        when(actions.existsByUserIdAndActionKey(7L, "education_modul-1"))
                .thenReturn(false);
        when(actions.findByUserIdOrderByCreatedAtAsc(7L))
                .thenReturn(List.of());

        EducationCompletionResponse response =
                service.complete(user, "modul-1");

        assertFalse(response.newlyCompleted());
        assertEquals(30, response.pointsAwarded());
        assertEquals(40, response.totalPoints());
        verify(progress, never()).save(any());
        verify(actions).save(any());
    }
}
