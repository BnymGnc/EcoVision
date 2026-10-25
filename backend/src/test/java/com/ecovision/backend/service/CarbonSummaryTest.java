package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.CarbonAssessment;
import com.ecovision.backend.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.any;

class CarbonSummaryTest {
    private final CarbonAssessmentRepository assessments = mock(CarbonAssessmentRepository.class);
    private final GamificationService gamification = mock(GamificationService.class);
    private final CarbonService service = new CarbonService(assessments, mock(WasteActionRepository.class),
            mock(AppUserRepository.class), gamification, new ObjectMapper(), mock(ScanHistoryRepository.class));

    private AppUser user() { var u = new AppUser(); u.setId(10L); return u; }

    @Test void emptySummaryDoesNotInventMeasuredSavingsOrAnnualEmissions() {
        when(assessments.findTopByUserIdOrderByCreatedAtDescIdDesc(10L)).thenReturn(Optional.empty());
        assertNull(service.summary(user()).latestAnnualKg());
    }

    @Test void zeroAndPositiveSurveyResultsAreReadWithoutConvertingToSavings() {
        for (int kg : new int[]{0, 4210}) {
            when(assessments.findTopByUserIdOrderByCreatedAtDescIdDesc(10L)).thenReturn(Optional.of(
                    new CarbonAssessment(user(), "{}", "{\"annualKnownKg\":" + kg + ",\"evidence\":\"SURVEY_ESTIMATE\"}")));
            var summary = service.summary(user());
            assertEquals((double) kg, summary.latestAnnualKg());
            assertEquals("SURVEY_ESTIMATE", summary.assessmentEvidence());
        }
    }

    @Test void repeatedSurveyStillPersistsUpdatedEstimateThroughExistingOneTimeRewardService() {
        var user = user();
        service.completeSurvey(user, 4000);
        service.completeSurvey(user, 3200);
        verify(gamification).completeCarbonFootprint(user, 4000);
        verify(gamification).completeCarbonFootprint(user, 3200);
        var saved = org.mockito.ArgumentCaptor.forClass(CarbonAssessment.class);
        verify(assessments, times(2)).save(saved.capture());
        assertTrue(saved.getAllValues().get(1).getResultJson().contains("3200"));
        assertThrows(IllegalArgumentException.class, () -> service.completeSurvey(user, -1));
    }
}
