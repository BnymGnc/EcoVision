package com.ecovision.backend.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.QuestRepository;
import com.ecovision.backend.repository.UserQuestProgressRepository;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class QuestSchedulingServiceTest {
    @Mock
    private QuestRepository questRepository;
    @Mock
    private UserQuestProgressRepository progressRepository;
    @Mock
    private AppUserRepository userRepository;

    @Test
    void archivesExpiredProgressAndAssignsThreeDailyQuests() {
        AppUser activeUser = new AppUser();
        activeUser.setId(9L);
        List<Quest> dailyCatalog = List.of(
                daily("Bir"),
                daily("İki"),
                daily("Üç"),
                daily("Dört"),
                daily("Beş")
        );
        when(questRepository.findByActiveTrueAndQuestCategory(
                QuestCategory.DAILY
        )).thenReturn(dailyCatalog);
        when(userRepository.findByLastLoginDateGreaterThanEqual(
                any(LocalDate.class)
        )).thenReturn(List.of(activeUser));

        QuestSchedulingService service = new QuestSchedulingService(
                questRepository,
                progressRepository,
                userRepository
        );
        service.initializeCurrentDailyAssignments();

        verify(progressRepository).archiveExpiredUncompleted(any());
        verify(progressRepository, times(3)).save(any());
    }

    private Quest daily(String title) {
        Quest quest = new Quest();
        quest.setCode("daily_" + title);
        quest.setTitle(title);
        quest.setDescription("Günlük görev");
        quest.setRewardPoints(10);
        quest.setTargetAmount(1);
        quest.setQuestCategory(QuestCategory.DAILY);
        return quest;
    }
}
