package com.ecovision.backend.service;

import com.ecovision.backend.dto.QuestClaimResponse;
import com.ecovision.backend.dto.QuestProgressResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.UserQuestProgress;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.QuestRepository;
import com.ecovision.backend.repository.UserQuestProgressRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuestCatalogService {
    private final QuestRepository questRepository;
    private final UserQuestProgressRepository progressRepository;
    private final AppUserRepository userRepository;
    private final QuestEngineService questEngineService;
    private final ObjectMapper objectMapper;

    public QuestCatalogService(
            QuestRepository questRepository,
            UserQuestProgressRepository progressRepository,
            AppUserRepository userRepository,
            QuestEngineService questEngineService,
            ObjectMapper objectMapper
    ) {
        this.questRepository = questRepository;
        this.progressRepository = progressRepository;
        this.userRepository = userRepository;
        this.questEngineService = questEngineService;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public List<QuestProgressResponse> catalog(AppUser user) {
        Instant now = Instant.now();
        Map<Long, UserQuestProgress> latestProgress = new HashMap<>();
        for (UserQuestProgress progress : progressRepository
                .findByUserIdAndArchivedAtIsNullOrderByAssignedAtDesc(user.getId())) {
            if (progress.getExpiresAt() != null
                    && !progress.getExpiresAt().isAfter(now)) {
                continue;
            }
            latestProgress.putIfAbsent(progress.getQuest().getId(), progress);
        }

        return questRepository.findByActiveTrueOrderByIdAsc()
                .stream()
                .map(quest -> toResponse(
                        quest,
                        latestProgress.get(quest.getId()),
                        now
                ))
                .toList();
    }

    @Transactional
    public QuestProgressResponse checkIn(AppUser currentUser, Long questId) {
        AppUser user = userRepository.findByIdForUpdate(currentUser.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Kullanıcı bulunamadı"
                ));
        Quest quest = questRepository.findById(questId)
                .filter(Quest::isActive)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Görev bulunamadı"
                ));
        Map<String, Object> criteria = readJson(quest.getCriteriaJson());
        if (!Boolean.TRUE.equals(criteria.get("selfReport"))) {
            throw new IllegalArgumentException(
                    "Bu görevin ilerlemesi uygulamadaki eylemlerle otomatik ölçülür"
            );
        }

        Instant now = Instant.now();
        UserQuestProgress progress = currentProgressForUpdate(
                user,
                quest,
                now
        );
        if (progress.isCompleted()) {
            throw new IllegalArgumentException("Bu görev zaten tamamlandı");
        }

        Map<String, Object> state = readJson(progress.getStateJson());
        String today = LocalDate.now(QuestEngineService.QUEST_ZONE).toString();
        List<String> checkInDates = stringList(state.get("checkInDates"));
        boolean oncePerDay = Boolean.TRUE.equals(criteria.get("oncePerDay"));
        if (oncePerDay && checkInDates.contains(today)) {
            throw new IllegalArgumentException(
                    "Bu görev için bugünkü ilerlemeni zaten kaydettin"
            );
        }

        if (oncePerDay) {
            checkInDates.add(today);
            state.put("checkInDates", checkInDates);
        }
        progress.setCurrentAmount(Math.min(
                progress.getCurrentAmount() + 1,
                quest.getTargetAmount()
        ));
        progress.setStateJson(writeJson(state));
        if (progress.getCurrentAmount() >= quest.getTargetAmount()) {
            progress.setCompleted(true);
            progress.setCompletedAt(now);
        }
        progress = progressRepository.save(progress);
        return toResponse(quest, progress, now);
    }

    @Transactional
    public QuestClaimResponse claim(AppUser currentUser, Long progressId) {
        UserQuestProgress before = progressRepository.findById(progressId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Görev ilerlemesi bulunamadı"
                ));
        if (!before.getUser().getId().equals(currentUser.getId())) {
            throw new IllegalArgumentException("Bu görev başka bir kullanıcıya ait");
        }
        boolean wasClaimed = before.isClaimed();
        int reward = before.getQuest().getRewardPoints();

        UserQuestProgress claimed = questEngineService.claim(
                currentUser.getId(),
                progressId
        );
        AppUser updatedUser = userRepository.findById(currentUser.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Kullanıcı bulunamadı"
                ));
        int awarded = wasClaimed ? 0 : reward;
        return new QuestClaimResponse(
                toResponse(claimed.getQuest(), claimed, Instant.now()),
                awarded,
                updatedUser.getTotalPoints(),
                awarded > 0
                        ? "Tebrikler! Görev ödülü hesabına eklendi."
                        : "Bu görev ödülü daha önce alınmış."
        );
    }

    private UserQuestProgress currentProgressForUpdate(
            AppUser user,
            Quest quest,
            Instant now
    ) {
        List<UserQuestProgress> candidates = progressRepository
                .findByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
                        user.getId(),
                        quest.getId()
                );
        for (UserQuestProgress candidate : candidates) {
            if (candidate.getExpiresAt() == null
                    || candidate.getExpiresAt().isAfter(now)) {
                return candidate;
            }
            candidate.setArchivedAt(now);
            progressRepository.save(candidate);
        }

        UserQuestProgress progress = new UserQuestProgress();
        progress.setUser(user);
        progress.setQuest(quest);
        progress.setAssignedAt(now);
        progress.setExpiresAt(QuestEngineService.expiryFor(
                quest.getQuestCategory(),
                now
        ));
        return progressRepository.save(progress);
    }

    private QuestProgressResponse toResponse(
            Quest quest,
            UserQuestProgress progress,
            Instant now
    ) {
        Map<String, Object> criteria = readJson(quest.getCriteriaJson());
        boolean selfReported = Boolean.TRUE.equals(criteria.get("selfReport"));
        boolean checkedToday = false;
        if (progress != null) {
            String today = LocalDate.now(QuestEngineService.QUEST_ZONE).toString();
            checkedToday = stringList(
                    readJson(progress.getStateJson()).get("checkInDates")
            ).contains(today);
        }
        boolean checkInAvailable = selfReported
                && (progress == null || !progress.isCompleted())
                && (!Boolean.TRUE.equals(criteria.get("oncePerDay"))
                || !checkedToday);

        return new QuestProgressResponse(
                quest.getId(),
                progress == null ? null : progress.getId(),
                quest.getCode(),
                quest.getTitle(),
                quest.getDescription(),
                quest.getRewardPoints(),
                quest.getTargetAmount(),
                quest.getQuestCategory().name(),
                quest.getDomain() == null
                        ? "ECO_IMPACT"
                        : quest.getDomain().name(),
                progress == null ? 0 : progress.getCurrentAmount(),
                progress != null && progress.isCompleted(),
                progress != null && progress.isClaimed(),
                checkInAvailable,
                progress == null ? null : progress.getExpiresAt()
        );
    }

    private Map<String, Object> readJson(String json) {
        if (json == null || json.isBlank()) {
            return new LinkedHashMap<>();
        }
        try {
            return objectMapper.readValue(
                    json,
                    new TypeReference<LinkedHashMap<String, Object>>() {
                    }
            );
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Görev verisi okunamadı", exception);
        }
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Görev verisi yazılamadı", exception);
        }
    }

    private List<String> stringList(Object value) {
        List<String> result = new ArrayList<>();
        if (value instanceof Iterable<?> values) {
            for (Object item : values) {
                result.add(String.valueOf(item));
            }
        }
        return result;
    }
}
