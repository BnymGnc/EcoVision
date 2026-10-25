package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.model.UserQuestProgress;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.QuestRepository;
import com.ecovision.backend.repository.UserQuestProgressRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class QuestEngineServiceTest {
    @Mock
    private QuestRepository questRepository;
    @Mock
    private UserQuestProgressRepository progressRepository;
    @Mock
    private AppUserRepository userRepository;

    private QuestEngineService engine;
    private AppUser user;

    @BeforeEach
    void setUp() {
        engine = new QuestEngineService(
                questRepository,
                progressRepository,
                userRepository,
                new ObjectMapper()
        );
        user = new AppUser();
        user.setId(7L);
        user.setTotalPoints(0);
        user.setLifetimePoints(0);
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
    }

    @Test
    void dispatchesByTriggerAndCompletesMatchingWasteQuest() {
        stubProgressSave();
        Quest quest = quest(
                11L,
                "Başlık değerlendirmede kullanılmıyor",
                1,
                QuestTriggerType.SCAN_SPECIFIC_WASTE,
                """
                        {"action":"scan","wasteTypes":["plastic"]}
                        """
        );
        when(questRepository.findByActiveTrueAndTriggerType(
                QuestTriggerType.SCAN_SPECIFIC_WASTE
        )).thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        List.of(11L)
                )).thenReturn(List.of());

        var updated = engine.evaluate(
                new QuestEvent(
                        7L,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        1,
                        Instant.now(),
                        Map.of("action", "scan", "wasteType", "plastic")
                )
        );

        assertEquals(1, updated.size());
        assertEquals(1, updated.get(0).getCurrentAmount());
        assertTrue(updated.get(0).isCompleted());
    }

    @Test
    void ignoresEventWhoseCriteriaDoesNotMatch() {
        Quest quest = quest(
                11L,
                "Cam görevi",
                2,
                QuestTriggerType.SCAN_SPECIFIC_WASTE,
                """
                        {"action":"scan","wasteTypes":["glass"]}
                        """
        );
        when(questRepository.findByActiveTrueAndTriggerType(
                QuestTriggerType.SCAN_SPECIFIC_WASTE
        )).thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        List.of(11L)
                )).thenReturn(List.of());

        var updated = engine.evaluate(
                QuestEvent.of(
                        7L,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        1,
                        Map.of("action", "scan", "wasteType", "plastic")
                )
        );

        assertTrue(updated.isEmpty());
        verify(progressRepository, never()).save(any(UserQuestProgress.class));
    }

    @Test
    void tracksCompoundWasteRequirementsInProgressState() {
        stubProgressSave();
        Quest quest = quest(
                11L,
                "Seviye 5 Kilidi",
                5,
                QuestTriggerType.SCAN_SPECIFIC_WASTE,
                """
                        {
                          "action":"scan",
                          "requirements":{"glass":3,"plastic":2}
                        }
                        """
        );
        UserQuestProgress progress = new UserQuestProgress();
        progress.setUser(user);
        progress.setQuest(quest);
        progress.setCurrentAmount(2);
        progress.setStateJson("""
                {"counts":{"glass":2}}
                """);
        when(questRepository.findByActiveTrueAndTriggerType(
                QuestTriggerType.SCAN_SPECIFIC_WASTE
        )).thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        List.of(11L)
                )).thenReturn(List.of(progress));

        var updated = engine.evaluate(
                QuestEvent.of(
                        7L,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        1,
                        Map.of("action", "scan", "wasteType", "plastic")
                )
        );

        assertEquals(3, updated.get(0).getCurrentAmount());
        assertFalse(updated.get(0).isCompleted());
        assertTrue(updated.get(0).getStateJson().contains("plastic"));
    }

    @Test
    void loadsProgressOnceForTriggeredQuestIdsAndUpdatesLatestAssignments() {
        stubProgressSave();
        Instant occurredAt = Instant.parse("2026-10-21T09:00:00Z");
        Quest firstQuest = quest(11L, "First quest", 5, QuestTriggerType.INVITE_FRIEND, "{}");
        Quest secondQuest = quest(12L, "Second quest", 5, QuestTriggerType.INVITE_FRIEND, "{}");
        UserQuestProgress firstOlder = progress(firstQuest, occurredAt.minusSeconds(120), 4);
        UserQuestProgress secondOlder = progress(secondQuest, occurredAt.minusSeconds(90), 4);
        UserQuestProgress firstLatest = progress(firstQuest, occurredAt.minusSeconds(60), 1);
        UserQuestProgress secondLatest = progress(secondQuest, occurredAt.minusSeconds(30), 2);
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(firstQuest, secondQuest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L, 12L)
                )).thenReturn(List.of(secondLatest, firstLatest, secondOlder, firstOlder));

        var updated = engine.evaluate(new QuestEvent(
                7L, QuestTriggerType.INVITE_FRIEND, 1, occurredAt, Map.of()
        ));

        assertEquals(2, updated.size());
        assertSame(firstLatest, updated.get(0));
        assertSame(secondLatest, updated.get(1));
        assertEquals(2, firstLatest.getCurrentAmount());
        assertEquals(3, secondLatest.getCurrentAmount());
        assertEquals(4, firstOlder.getCurrentAmount());
        assertEquals(4, secondOlder.getCurrentAmount());
        verify(progressRepository, times(1))
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L, 12L)
                );
        verify(progressRepository, never())
                .findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(any(), any());
        verify(progressRepository).save(firstLatest);
        verify(progressRepository).save(secondLatest);
        verifyNoMoreInteractions(progressRepository);
    }

    @Test
    void skipsProgressQueryWhenNoActiveQuestsMatchTrigger() {
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of());

        var updated = engine.evaluate(QuestEvent.of(
                7L, QuestTriggerType.INVITE_FRIEND, 1, Map.of()
        ));

        assertTrue(updated.isEmpty());
        verifyNoInteractions(progressRepository);
    }

    @Test
    void doesNotCreateUnassignedDailyProgress() {
        Quest quest = quest(11L, "Daily quest", 3, QuestTriggerType.INVITE_FRIEND, "{}");
        quest.setQuestCategory(QuestCategory.DAILY);
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                )).thenReturn(List.of());

        var updated = engine.evaluate(QuestEvent.of(
                7L, QuestTriggerType.INVITE_FRIEND, 1, Map.of()
        ));

        assertTrue(updated.isEmpty());
        verify(progressRepository)
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                );
        verifyNoMoreInteractions(progressRepository);
    }

    @Test
    void completesAssignedDailyProgressWithoutAwardingPoints() {
        stubProgressSave();
        Instant occurredAt = Instant.parse("2026-10-21T09:00:00Z");
        Quest quest = quest(11L, "Daily quest", 3, QuestTriggerType.INVITE_FRIEND, "{}");
        quest.setQuestCategory(QuestCategory.DAILY);
        UserQuestProgress progress = progress(quest, occurredAt.minusSeconds(60), 1);
        progress.setExpiresAt(occurredAt.plusSeconds(1));
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                )).thenReturn(List.of(progress));

        var updated = engine.evaluate(new QuestEvent(
                7L, QuestTriggerType.INVITE_FRIEND, 10, occurredAt, Map.of()
        ));

        assertEquals(1, updated.size());
        assertSame(progress, updated.get(0));
        assertEquals(3, progress.getCurrentAmount());
        assertTrue(progress.isCompleted());
        assertEquals(occurredAt, progress.getCompletedAt());
        assertEquals(occurredAt.minusSeconds(60), progress.getAssignedAt());
        assertEquals(occurredAt.plusSeconds(1), progress.getExpiresAt());
        assertFalse(progress.isClaimed());
        assertEquals(0, user.getTotalPoints());
        assertEquals(0, user.getLifetimePoints());
        verify(userRepository).findById(7L);
        verifyNoMoreInteractions(userRepository);
    }

    @ParameterizedTest
    @EnumSource(QuestCategory.class)
    void completedLatestAssignmentBlocksOlderProgress(QuestCategory category) {
        Instant occurredAt = Instant.parse("2026-10-21T09:00:00Z");
        Quest quest = quest(11L, "Completed quest", 5, QuestTriggerType.INVITE_FRIEND, "{}");
        quest.setQuestCategory(category);
        UserQuestProgress older = progress(quest, occurredAt.minusSeconds(120), 1);
        UserQuestProgress latest = progress(quest, occurredAt.minusSeconds(60), 5);
        latest.setCompleted(true);
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                )).thenReturn(List.of(latest, older));

        var updated = engine.evaluate(new QuestEvent(
                7L, QuestTriggerType.INVITE_FRIEND, 1, occurredAt, Map.of()
        ));

        assertTrue(updated.isEmpty());
        assertEquals(1, older.getCurrentAmount());
        assertEquals(5, latest.getCurrentAmount());
        verify(progressRepository)
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                );
        verifyNoMoreInteractions(progressRepository);
    }

    @ParameterizedTest
    @ValueSource(longs = {-1, 0})
    void expiredLatestAssignmentBlocksOlderProgress(long expiryOffsetSeconds) {
        Instant occurredAt = Instant.parse("2026-10-21T09:00:00Z");
        Quest quest = quest(11L, "Expired quest", 5, QuestTriggerType.INVITE_FRIEND, "{}");
        quest.setQuestCategory(QuestCategory.WEEKLY);
        UserQuestProgress older = progress(quest, occurredAt.minusSeconds(120), 1);
        older.setExpiresAt(occurredAt.plusSeconds(3600));
        UserQuestProgress latest = progress(quest, occurredAt.minusSeconds(60), 2);
        latest.setExpiresAt(occurredAt.plusSeconds(expiryOffsetSeconds));
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                )).thenReturn(List.of(latest, older));

        var updated = engine.evaluate(new QuestEvent(
                7L, QuestTriggerType.INVITE_FRIEND, 1, occurredAt, Map.of()
        ));

        assertTrue(updated.isEmpty());
        assertEquals(1, older.getCurrentAmount());
        assertEquals(2, latest.getCurrentAmount());
        verify(progressRepository)
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                );
        verifyNoMoreInteractions(progressRepository);
    }

    @ParameterizedTest
    @EnumSource(value = QuestCategory.class, mode = EnumSource.Mode.EXCLUDE, names = "DAILY")
    void createsUnassignedNonDailyProgressWithExistingExpiryRules(QuestCategory category) {
        stubProgressSave();
        Instant occurredAt = Instant.parse("2026-10-21T09:00:00Z");
        Quest quest = quest(11L, "New quest", 3, QuestTriggerType.INVITE_FRIEND, "{}");
        quest.setQuestCategory(category);
        when(questRepository.findByActiveTrueAndTriggerType(QuestTriggerType.INVITE_FRIEND))
                .thenReturn(List.of(quest));
        when(progressRepository
                .findByUserIdAndQuestIdInAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L, List.of(11L)
                )).thenReturn(List.of());

        var updated = engine.evaluate(new QuestEvent(
                7L, QuestTriggerType.INVITE_FRIEND, 1, occurredAt, Map.of()
        ));

        assertEquals(1, updated.size());
        UserQuestProgress progress = updated.get(0);
        assertSame(user, progress.getUser());
        assertSame(quest, progress.getQuest());
        assertEquals(occurredAt, progress.getAssignedAt());
        assertEquals(
                category == QuestCategory.WEEKLY ? Instant.parse("2026-10-25T21:00:00Z") : null,
                progress.getExpiresAt()
        );
        assertEquals(1, progress.getCurrentAmount());
        assertFalse(progress.isCompleted());
    }

    private UserQuestProgress progress(Quest quest, Instant assignedAt, int amount) {
        UserQuestProgress progress = new UserQuestProgress();
        progress.setUser(user);
        progress.setQuest(quest);
        progress.setAssignedAt(assignedAt);
        progress.setCurrentAmount(amount);
        return progress;
    }

    private Quest quest(
            Long id,
            String title,
            int target,
            QuestTriggerType trigger,
            String criteria
    ) {
        Quest quest = new Quest();
        ReflectionTestUtils.setField(quest, "id", id);
        quest.setCode("test_" + title.hashCode());
        quest.setTitle(title);
        quest.setDescription("Test görevi");
        quest.setRewardPoints(10);
        quest.setTargetAmount(target);
        quest.setQuestCategory(QuestCategory.MILESTONE);
        quest.setTriggerType(trigger);
        quest.setCriteriaJson(criteria);
        return quest;
    }

    private void stubProgressSave() {
        when(progressRepository.save(any(UserQuestProgress.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }
}
