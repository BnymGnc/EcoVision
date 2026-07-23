package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
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
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

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
                .findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        null
                )).thenReturn(Optional.empty());

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
        assertEquals(1, updated.getFirst().getCurrentAmount());
        assertTrue(updated.getFirst().isCompleted());
    }

    @Test
    void ignoresEventWhoseCriteriaDoesNotMatch() {
        Quest quest = quest(
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
                .findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        null
                )).thenReturn(Optional.empty());

        var updated = engine.evaluate(
                QuestEvent.of(
                        7L,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        1,
                        Map.of("action", "scan", "wasteType", "plastic")
                )
        );

        assertTrue(updated.isEmpty());
    }

    @Test
    void tracksCompoundWasteRequirementsInProgressState() {
        stubProgressSave();
        Quest quest = quest(
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
                .findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
                        7L,
                        null
                )).thenReturn(Optional.of(progress));

        var updated = engine.evaluate(
                QuestEvent.of(
                        7L,
                        QuestTriggerType.SCAN_SPECIFIC_WASTE,
                        1,
                        Map.of("action", "scan", "wasteType", "plastic")
                )
        );

        assertEquals(3, updated.getFirst().getCurrentAmount());
        assertFalse(updated.getFirst().isCompleted());
        assertTrue(updated.getFirst().getStateJson().contains("plastic"));
    }

    private Quest quest(
            String title,
            int target,
            QuestTriggerType trigger,
            String criteria
    ) {
        Quest quest = new Quest();
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
