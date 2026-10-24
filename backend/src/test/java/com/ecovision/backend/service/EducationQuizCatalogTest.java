package com.ecovision.backend.service;
import org.junit.jupiter.api.Test;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
class EducationQuizCatalogTest {
    @Test void answersAreGradedByServerAndVersionRequired() throws Exception {
        var quiz = new EducationQuizCatalog(new ObjectMapper());
        assertThrows(org.springframework.web.server.ResponseStatusException.class, () -> quiz.requirePassing("modul-1",null));
        assertThrows(org.springframework.web.server.ResponseStatusException.class, () -> quiz.requirePassing("modul-1",
            new EducationQuizCatalog.Submission("old",List.of(1,0,2))));
        for(var answers:List.of(List.of(0,1,0),List.of(1,1,0))) {
            assertThrows(org.springframework.web.server.ResponseStatusException.class,()->quiz.requirePassing("modul-1",
                new EducationQuizCatalog.Submission("2026-10-24-v1",answers)));
        }
        for(var answers:List.of(List.of(1,0,0),List.of(1,0,2))) {
            assertDoesNotThrow(()->quiz.requirePassing("modul-1",new EducationQuizCatalog.Submission("2026-10-24-v1",answers)));
        }
        assertThrows(IllegalArgumentException.class,()->quiz.requirePassing("modul-1",
            new EducationQuizCatalog.Submission("2026-10-24-v1",List.of(99,0,2))));
    }
    @Test void tenModulesArePublishedWithoutAnAnswerKey() throws Exception {
        var quiz = new EducationQuizCatalog(new ObjectMapper());
        for(int i=1;i<=10;i++) {
            var json = new ObjectMapper().writeValueAsString(quiz.publicQuiz("modul-"+i));
            assertFalse(json.contains("correctOptionIndex"));
            assertTrue(json.contains("quizVersion"));
        }
    }
}
