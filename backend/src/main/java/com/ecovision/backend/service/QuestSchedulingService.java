package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.UserQuestProgress;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.QuestRepository;
import com.ecovision.backend.repository.UserQuestProgressRepository;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuestSchedulingService {
    private static final int DAILY_QUESTS_PER_USER = 3;
    private static final int ACTIVE_USER_WINDOW_DAYS = 30;

    private final QuestRepository questRepository;
    private final UserQuestProgressRepository progressRepository;
    private final AppUserRepository userRepository;
    private final SecureRandom random = new SecureRandom();

    public QuestSchedulingService(
            QuestRepository questRepository,
            UserQuestProgressRepository progressRepository,
            AppUserRepository userRepository
    ) {
        this.questRepository = questRepository;
        this.progressRepository = progressRepository;
        this.userRepository = userRepository;
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void initializeCurrentDailyAssignments() {
        rotateDailyQuests();
    }

    @Scheduled(cron = "0 0 0 * * *", zone = "Europe/Istanbul")
    @Transactional
    public void rotateDailyQuestsAtMidnight() {
        rotateDailyQuests();
    }

    private void rotateDailyQuests() {
        Instant now = Instant.now();
        progressRepository.archiveExpiredUncompleted(now);

        List<Quest> dailyCatalog = questRepository
                .findByActiveTrueAndQuestCategory(QuestCategory.DAILY);
        if (dailyCatalog.isEmpty()) {
            return;
        }

        LocalDate activeSince = LocalDate.now(QuestEngineService.QUEST_ZONE)
                .minusDays(ACTIVE_USER_WINDOW_DAYS);
        for (AppUser user : userRepository
                .findByLastLoginDateGreaterThanEqual(activeSince)) {
            assignRandomDailyQuests(user, dailyCatalog, now);
        }
    }

    private void assignRandomDailyQuests(
            AppUser user,
            List<Quest> dailyCatalog,
            Instant now
    ) {
        List<Quest> candidates = new ArrayList<>(dailyCatalog);
        Collections.shuffle(candidates, random);
        int assigned = 0;
        for (Quest quest : candidates) {
            if (progressRepository
                    .existsByUserIdAndQuestIdAndArchivedAtIsNullAndExpiresAtAfter(
                            user.getId(),
                            quest.getId(),
                            now
                    )) {
                continue;
            }
            UserQuestProgress progress = new UserQuestProgress();
            progress.setUser(user);
            progress.setQuest(quest);
            progress.setAssignedAt(now);
            progress.setExpiresAt(
                    QuestEngineService.expiryFor(QuestCategory.DAILY, now)
            );
            progressRepository.save(progress);
            assigned++;
            if (assigned == Math.min(DAILY_QUESTS_PER_USER, dailyCatalog.size())) {
                break;
            }
        }
    }
}
