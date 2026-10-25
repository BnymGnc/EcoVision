package com.ecovision.backend.service;

import com.ecovision.backend.model.*;
import com.ecovision.backend.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CarbonService {
    private final CarbonAssessmentRepository assessments;
    private final WasteActionRepository actions;
    private final AppUserRepository users;
    private final GamificationService gamification;
    private final ObjectMapper mapper;
    private final ScanHistoryRepository scans;
    public CarbonService(CarbonAssessmentRepository assessments, WasteActionRepository actions,
                         AppUserRepository users, GamificationService gamification, ObjectMapper mapper,
                         ScanHistoryRepository scans) {
        this.assessments = assessments; this.actions = actions; this.users = users;
        this.gamification = gamification; this.mapper = mapper;
        this.scans = scans;
    }
    @Transactional
    public Map<String, Object> assess(AppUser user, CarbonMath.Inputs input) throws Exception {
        var result = CarbonMath.assess(input);
        if (result.annualKnownKg() == null) throw new IllegalArgumentException("En az bir gerçek tüketim değeri girilmelidir");
        var saved = assessments.save(new CarbonAssessment(user, mapper.writeValueAsString(input), mapper.writeValueAsString(result)));
        var reward = gamification.completeCarbonFootprint(user, (int)Math.round(result.annualKnownKg()));
        return Map.of("id", saved.getId(), "assessment", result, "gamification", reward);
    }
    @Transactional(readOnly = true)
    public List<Map<String, Object>> history(AppUser user) {
        return assessments.findTop12ByUserIdOrderByCreatedAtDesc(user.getId()).stream().map(row -> {
            try { return Map.<String, Object>of("id", row.getId(), "createdAt", row.getCreatedAt(), "assessment", mapper.readTree(row.getResultJson())); }
            catch (Exception failure) { throw new IllegalStateException("Karbon kaydı okunamadı", failure); }
        }).toList();
    }

    @Transactional
    public com.ecovision.backend.dto.GamificationResponse completeSurvey(AppUser user, int annualKg) {
        if (annualKg < 0 || annualKg > 50_000_000) {
            throw new IllegalArgumentException("Geçersiz karbon tahmini");
        }
        // Keep the existing fixed, one-time reward; each new survey stores its latest estimate.
        var reward = gamification.completeCarbonFootprint(user, annualKg);
        var result = mapper.createObjectNode();
        result.put("annualKnownKg", annualKg);
        result.put("evidence", "SURVEY_ESTIMATE");
        result.put("scope", "Yaklaşık yıllık anket tahmini; ölçülmüş karbon tasarrufu değildir.");
        assessments.save(new CarbonAssessment(user, "{\"source\":\"SURVEY\"}", result.toString()));
        return reward;
    }
    @Transactional
    public ActionResponse saveAction(AppUser user, ActionRequest request) {
        users.findByIdForUpdate(user.getId()).orElseThrow();
        if (request.actionKey() == null || request.actionKey().isBlank() || request.actionKey().length() > 80
                || request.material() == null || request.material().length() > 30 || request.massKg() <= 0
                || request.massKg() > 1000 || !Double.isFinite(request.massKg())
                || request.baseline() == null || request.selected() == null
                || !Set.of("LANDFILL", "RECYCLING").contains(request.baseline())
                || !Set.of("LANDFILL", "RECYCLING").contains(request.selected()))
            throw new IllegalArgumentException("Eylem, malzeme, gramaj veya yönetim yolu geçersiz");
        var existing = actions.findByUserIdAndActionKey(user.getId(), request.actionKey());
        if (existing.isPresent()) return ActionResponse.from(existing.get());
        Double difference = CarbonMath.wasteDifference(request.material(), request.massKg(), request.baseline(), request.selected());
        return ActionResponse.from(actions.save(new WasteAction(user, request.actionKey(), request.material(),
                request.massKg(), request.baseline(), request.selected(), difference, CarbonMath.VERSION)));
    }
    @Transactional(readOnly = true)
    public Summary summary(AppUser user) {
        Double annualKg = null;
        String assessmentEvidence = null;
        var latest = assessments.findTopByUserIdOrderByCreatedAtDescIdDesc(user.getId());
        if (latest.isPresent()) {
            try {
                var result = mapper.readTree(latest.get().getResultJson());
                var amount = result.path("annualKnownKg");
                if (amount.isNumber() && Double.isFinite(amount.asDouble()) && amount.asDouble() >= 0) {
                    annualKg = amount.asDouble();
                    assessmentEvidence = result.path("evidence").asText("CONSUMPTION_ESTIMATE");
                }
            } catch (com.fasterxml.jackson.core.JsonProcessingException failure) {
                throw new IllegalStateException("Karbon kaydı okunamadı", failure);
            }
        }
        return new Summary(actions.countByUserId(user.getId()), actions.totalForUser(user.getId()),
                "USER_DECLARED", CarbonMath.VERSION, annualKg, assessmentEvidence,
                RecyclingPotential.estimate(scans.recyclingCounts(user.getId())));
    }
    @Transactional(readOnly = true)
    public List<ActionResponse> actions(AppUser user) {
        return actions.findTop100ByUserIdOrderByCreatedAtDesc(user.getId()).stream().map(ActionResponse::from).toList();
    }
    @Transactional
    public ActionResponse updateMass(AppUser user, Long id, double massKg) {
        users.findByIdForUpdate(user.getId()).orElseThrow();
        if (!Double.isFinite(massKg) || massKg <= 0 || massKg > 1000)
            throw new IllegalArgumentException("Gramaj sıfırdan büyük ve en fazla 1000 kg olmalıdır");
        var action = actions.findById(id).filter(row -> row.getUser().getId().equals(user.getId())).orElseThrow(
                () -> new IllegalArgumentException("Eylem bulunamadı"));
        action.reviseMass(massKg, CarbonMath.wasteDifference(action.getMaterial(), massKg,
                action.getBaseline(), action.getSelected()), CarbonMath.VERSION);
        return ActionResponse.from(actions.save(action));
    }
    @Transactional
    public void deleteAction(AppUser user, Long id) {
        users.findByIdForUpdate(user.getId()).orElseThrow();
        var action = actions.findById(id).filter(row -> row.getUser().getId().equals(user.getId())).orElseThrow(
                () -> new IllegalArgumentException("Eylem bulunamadı"));
        actions.delete(action);
    }
    public record ActionRequest(String actionKey, String material, double massKg, String baseline, String selected) {}
    public record Summary(long declaredActionCount, Double estimatedDifferenceKg, String evidence,
                          String factorVersion, Double latestAnnualKg, String assessmentEvidence,
                          RecyclingPotential.Estimate recyclingPotential) {}
    public record ActionResponse(Long id, String material, double massKg, String baseline, String selected,
                                 Double estimatedDifferenceKg, String evidence, String factorVersion, java.time.Instant createdAt) {
        static ActionResponse from(WasteAction a) { return new ActionResponse(a.getId(), a.getMaterial(), a.getMassKg(),
                a.getBaseline(), a.getSelected(), a.getEstimatedDifferenceKg(), a.getEvidence(), a.getFactorVersion(), a.getCreatedAt()); }
    }
}
