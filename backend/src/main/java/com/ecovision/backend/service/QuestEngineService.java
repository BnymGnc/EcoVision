package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.model.UserQuestProgress;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.QuestRepository;
import com.ecovision.backend.repository.UserQuestProgressRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Service
public class QuestEngineService {
    static final ZoneId QUEST_ZONE = ZoneId.of("Europe/Istanbul");

    private final QuestRepository questRepository;
    private final UserQuestProgressRepository progressRepository;
    private final AppUserRepository userRepository;
    private final ObjectMapper objectMapper;
    private final Map<QuestTriggerType, QuestEvaluator> evaluators;

    public QuestEngineService(
            QuestRepository questRepository,
            UserQuestProgressRepository progressRepository,
            AppUserRepository userRepository,
            ObjectMapper objectMapper
    ) {
        this.questRepository = questRepository;
        this.progressRepository = progressRepository;
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
        this.evaluators = evaluatorRegistry();
    }

    @TransactionalEventListener(
            phase = TransactionPhase.AFTER_COMMIT,
            fallbackExecution = true
    )
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onQuestEvent(QuestEvent event) {
        evaluate(event);
    }

    @Transactional
    public List<UserQuestProgress> evaluate(QuestEvent event) {
        AppUser user = userRepository.findById(event.userId())
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        QuestEvaluator evaluator = evaluators.get(event.triggerType());
        if (evaluator == null) {
            throw new IllegalArgumentException(
                    "Desteklenmeyen görev tetikleyicisi: " + event.triggerType()
            );
        }

        List<UserQuestProgress> updated = new ArrayList<>();
        for (Quest quest : questRepository.findByActiveTrueAndTriggerType(
                event.triggerType()
        )) {
            UserQuestProgress progress = progressRepository
                    .findFirstByUserIdAndQuestIdAndArchivedAtIsNullOrderByAssignedAtDesc(
                            user.getId(),
                            quest.getId()
                    )
                    .orElse(null);

            if (progress == null && quest.getQuestCategory() == QuestCategory.DAILY) {
                continue;
            }
            if (progress != null && (progress.isCompleted() || isExpired(progress, event))) {
                continue;
            }
            if (progress == null) {
                progress = newProgress(user, quest, event.occurredAt());
            }

            Map<String, Object> criteria = readJson(quest.getCriteriaJson());
            EvaluationResult result = evaluator.evaluate(
                    quest,
                    progress,
                    event,
                    criteria
            );
            if (!result.matched()) {
                continue;
            }

            progress.setCurrentAmount(
                    Math.min(result.amount(), quest.getTargetAmount())
            );
            progress.setStateJson(result.stateJson());
            if (progress.getCurrentAmount() >= quest.getTargetAmount()) {
                progress.setCompleted(true);
                progress.setCompletedAt(event.occurredAt());
            }
            updated.add(progressRepository.save(progress));
        }
        return List.copyOf(updated);
    }

    @Transactional
    public UserQuestProgress claim(Long userId, Long progressId) {
        AppUser user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        UserQuestProgress progress = progressRepository.findByIdForUpdate(progressId)
                .orElseThrow(() -> new IllegalArgumentException("Görev ilerlemesi bulunamadı"));
        if (!progress.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("Bu görev başka bir kullanıcıya ait");
        }
        if (!progress.isCompleted()) {
            throw new IllegalArgumentException("Görev henüz tamamlanmadı");
        }
        if (progress.isClaimed()) {
            return progress;
        }

        int reward = progress.getQuest().getRewardPoints();
        user.setTotalPoints(user.getTotalPoints() + reward);
        user.setLifetimePoints(user.getLifetimePoints() + reward);
        progress.setClaimed(true);
        progress.setClaimedAt(Instant.now());
        userRepository.save(user);
        return progressRepository.save(progress);
    }

    private Map<QuestTriggerType, QuestEvaluator> evaluatorRegistry() {
        Map<QuestTriggerType, QuestEvaluator> registry =
                new EnumMap<>(QuestTriggerType.class);
        registry.put(QuestTriggerType.SCAN_SPECIFIC_WASTE, this::evaluateIncrement);
        registry.put(QuestTriggerType.REACH_SCORE, this::evaluateScore);
        registry.put(QuestTriggerType.BUY_MARKET_ITEM, this::evaluateIncrement);
        registry.put(QuestTriggerType.INVITE_FRIEND, this::evaluateIncrement);
        registry.put(QuestTriggerType.AI_CONFIDENCE_HIGH, this::evaluateIncrement);
        registry.put(QuestTriggerType.TIME_BASED, this::evaluateIncrement);
        registry.put(QuestTriggerType.LOCATION_BASED, this::evaluateIncrement);
        registry.put(QuestTriggerType.STREAK_DAYS, this::evaluateScore);
        return Map.copyOf(registry);
    }

    private EvaluationResult evaluateIncrement(
            Quest quest,
            UserQuestProgress progress,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!matchesCriteria(event, criteria)) {
            return EvaluationResult.noMatch(progress);
        }
        if (!matchesDeadline(progress, event, criteria)) {
            return EvaluationResult.noMatch(progress);
        }
        if (criteria.containsKey("requirements")) {
            return evaluateRequirements(progress, event, criteria);
        }
        String mode = text(criteria.get("mode"), "INCREMENT");
        if ("UNIQUE".equalsIgnoreCase(mode)) {
            return evaluateUnique(progress, event, criteria);
        }
        int amount = progress.getCurrentAmount() + Math.max(1, event.amount());
        return EvaluationResult.match(amount, progress.getStateJson());
    }

    private EvaluationResult evaluateScore(
            Quest quest,
            UserQuestProgress progress,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!matchesCriteria(event, criteria)) {
            return EvaluationResult.noMatch(progress);
        }
        if ("INCREMENT".equalsIgnoreCase(text(criteria.get("mode"), "MAX"))) {
            return EvaluationResult.match(
                    progress.getCurrentAmount() + Math.max(1, event.amount()),
                    progress.getStateJson()
            );
        }
        int value = integer(event.attributes().get("value"), event.amount());
        return EvaluationResult.match(
                Math.max(progress.getCurrentAmount(), value),
                progress.getStateJson()
        );
    }

    private EvaluationResult evaluateUnique(
            UserQuestProgress progress,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        String attributeName = text(criteria.get("uniqueAttribute"), "");
        Object rawValue = event.attributes().get(attributeName);
        if (attributeName.isBlank() || rawValue == null) {
            return EvaluationResult.noMatch(progress);
        }

        Map<String, Object> state = readJson(progress.getStateJson());
        resetPeriodicStateIfNeeded(state, event, criteria);
        Set<String> values = new LinkedHashSet<>(stringList(state.get("values")));
        values.add(normalize(rawValue.toString()));
        state.put("values", values);
        return EvaluationResult.match(values.size(), writeJson(state));
    }

    private EvaluationResult evaluateRequirements(
            UserQuestProgress progress,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        Object rawRequirements = criteria.get("requirements");
        if (!(rawRequirements instanceof Map<?, ?> requirements)) {
            return EvaluationResult.noMatch(progress);
        }
        String wasteType = normalize(
                text(event.attributes().get("wasteType"), "")
        );
        Object requiredValue = requirements.get(wasteType);
        if (requiredValue == null) {
            return EvaluationResult.noMatch(progress);
        }

        Map<String, Object> state = readJson(progress.getStateJson());
        Map<String, Integer> counts = new java.util.LinkedHashMap<>();
        Object rawCounts = state.get("counts");
        if (rawCounts instanceof Map<?, ?> existingCounts) {
            existingCounts.forEach(
                    (key, value) -> counts.put(
                            normalize(String.valueOf(key)),
                            integer(value, 0)
                    )
            );
        }
        counts.merge(wasteType, Math.max(1, event.amount()), Integer::sum);

        int total = 0;
        for (Map.Entry<?, ?> requirement : requirements.entrySet()) {
            String key = normalize(String.valueOf(requirement.getKey()));
            int required = integer(requirement.getValue(), 0);
            total += Math.min(counts.getOrDefault(key, 0), required);
        }
        state.put("counts", counts);
        return EvaluationResult.match(total, writeJson(state));
    }

    private void resetPeriodicStateIfNeeded(
            Map<String, Object> state,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!"DAY".equalsIgnoreCase(text(criteria.get("period"), ""))) {
            return;
        }
        String currentPeriod = event.occurredAt()
                .atZone(QUEST_ZONE)
                .toLocalDate()
                .toString();
        if (!currentPeriod.equals(state.get("period"))) {
            state.clear();
            state.put("period", currentPeriod);
        }
    }

    private boolean matchesDeadline(
            UserQuestProgress progress,
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!criteria.containsKey("expiresWithinMinutes")) {
            return true;
        }
        if (progress.getExpiresAt() == null) {
            return false;
        }
        long minutes = java.time.Duration.between(
                event.occurredAt(),
                progress.getExpiresAt()
        ).toMinutes();
        return minutes >= 0
                && minutes <= integer(criteria.get("expiresWithinMinutes"), 0);
    }

    private boolean matchesCriteria(
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        return matchesExpected(criteria.get("action"), event.attributes().get("action"))
                && matchesExpected(
                        criteria.get("metric"),
                        event.attributes().get("metric")
                )
                && matchesExpected(
                        criteria.get("wasteTypes"),
                        event.attributes().get("wasteType")
                )
                && matchesExpected(
                        criteria.get("itemIds"),
                        event.attributes().get("itemId")
                )
                && matchesExpected(
                        criteria.get("faction"),
                        event.attributes().get("faction")
                )
                && meetsConfidence(event, criteria)
                && matchesDay(event, criteria)
                && matchesTime(event, criteria);
    }

    private boolean matchesExpected(Object expected, Object actual) {
        if (expected == null) {
            return true;
        }
        if (actual == null) {
            return false;
        }
        Set<String> accepted = new LinkedHashSet<>(stringList(expected));
        return accepted.contains(normalize(actual.toString()));
    }

    private boolean meetsConfidence(
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!criteria.containsKey("minimumConfidence")) {
            return true;
        }
        double minimum = decimal(criteria.get("minimumConfidence"), 0);
        double confidence = decimal(event.attributes().get("confidence"), 0);
        return confidence >= minimum;
    }

    private boolean matchesDay(
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!criteria.containsKey("daysOfWeek")) {
            return true;
        }
        DayOfWeek current = event.occurredAt().atZone(QUEST_ZONE).getDayOfWeek();
        return stringList(criteria.get("daysOfWeek")).contains(
                normalize(current.name())
        );
    }

    private boolean matchesTime(
            QuestEvent event,
            Map<String, Object> criteria
    ) {
        if (!criteria.containsKey("startHour")
                || !criteria.containsKey("endHour")) {
            return true;
        }
        LocalTime current = event.occurredAt().atZone(QUEST_ZONE).toLocalTime();
        LocalTime start = LocalTime.of(integer(criteria.get("startHour"), 0), 0);
        LocalTime end = LocalTime.of(integer(criteria.get("endHour"), 23), 0);
        if (start.equals(end)) {
            return true;
        }
        if (start.isBefore(end)) {
            return !current.isBefore(start) && current.isBefore(end);
        }
        return !current.isBefore(start) || current.isBefore(end);
    }

    private UserQuestProgress newProgress(
            AppUser user,
            Quest quest,
            Instant assignedAt
    ) {
        UserQuestProgress progress = new UserQuestProgress();
        progress.setUser(user);
        progress.setQuest(quest);
        progress.setAssignedAt(assignedAt);
        progress.setExpiresAt(expiryFor(quest.getQuestCategory(), assignedAt));
        return progress;
    }

    static Instant expiryFor(QuestCategory category, Instant reference) {
        ZonedDateTime local = reference.atZone(QUEST_ZONE);
        if (category == QuestCategory.DAILY) {
            return local.toLocalDate().plusDays(1)
                    .atStartOfDay(QUEST_ZONE)
                    .toInstant();
        }
        if (category == QuestCategory.WEEKLY) {
            LocalDate nextMonday = local.toLocalDate()
                    .with(TemporalAdjusters.next(DayOfWeek.MONDAY));
            return nextMonday.atStartOfDay(QUEST_ZONE).toInstant();
        }
        return null;
    }

    private boolean isExpired(UserQuestProgress progress, QuestEvent event) {
        return progress.getExpiresAt() != null
                && !progress.getExpiresAt().isAfter(event.occurredAt());
    }

    private Map<String, Object> readJson(String json) {
        if (json == null || json.isBlank()) {
            return new java.util.LinkedHashMap<>();
        }
        try {
            return objectMapper.readValue(
                    json,
                    new TypeReference<java.util.LinkedHashMap<String, Object>>() {
                    }
            );
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Görev kriteri okunamadı", exception);
        }
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Görev durumu yazılamadı", exception);
        }
    }

    private List<String> stringList(Object value) {
        if (value == null) {
            return List.of();
        }
        if (value instanceof Iterable<?> values) {
            List<String> normalized = new ArrayList<>();
            for (Object item : values) {
                normalized.add(normalize(String.valueOf(item)));
            }
            return List.copyOf(normalized);
        }
        return List.of(normalize(value.toString()));
    }

    private String normalize(String value) {
        return value.trim().toLowerCase(Locale.ROOT);
    }

    private String text(Object value, String fallback) {
        return value == null ? fallback : value.toString();
    }

    private int integer(Object value, int fallback) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return value == null ? fallback : Integer.parseInt(value.toString());
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }

    private double decimal(Object value, double fallback) {
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        try {
            return value == null ? fallback : Double.parseDouble(value.toString());
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }

    @FunctionalInterface
    private interface QuestEvaluator {
        EvaluationResult evaluate(
                Quest quest,
                UserQuestProgress progress,
                QuestEvent event,
                Map<String, Object> criteria
        );
    }

    private record EvaluationResult(
            boolean matched,
            int amount,
            String stateJson
    ) {
        static EvaluationResult noMatch(UserQuestProgress progress) {
            return new EvaluationResult(
                    false,
                    progress.getCurrentAmount(),
                    progress.getStateJson()
            );
        }

        static EvaluationResult match(int amount, String stateJson) {
            return new EvaluationResult(true, amount, stateJson);
        }
    }
}
