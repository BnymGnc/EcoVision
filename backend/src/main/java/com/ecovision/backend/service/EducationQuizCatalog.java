package com.ecovision.backend.service;

import com.fasterxml.jackson.databind.*;
import java.util.*;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class EducationQuizCatalog {
    private final JsonNode catalog;
    public EducationQuizCatalog(ObjectMapper mapper) throws java.io.IOException {
        try (var input = new ClassPathResource("education/academy-quiz-v1.json").getInputStream()) {
            catalog = mapper.readTree(input);
        }
    }
    public record Submission(String quizVersion, List<Integer> answers) {}
    private JsonNode module(String id) {
        for (var module : catalog.path("modules")) if (module.path("categoryId").asText().equals(id)) return module;
        throw new IllegalArgumentException("Geçersiz akademi modülü");
    }
    public Map<String,Object> publicQuiz(String id) {
        var module = module(id);
        var questions = new ArrayList<Map<String,Object>>();
        for (var q : module.path("questions")) {
            var options = new ArrayList<String>();
            q.path("options").forEach(o -> options.add(o.asText()));
            questions.add(Map.of("questionText", q.path("questionText").asText(), "options", options));
        }
        return Map.of("categoryId", id, "quizVersion", catalog.path("version").asText(), "questions", questions);
    }
    public void requirePassing(String id, Submission submission) {
        var questions = module(id).path("questions");
        if (submission == null || submission.quizVersion() == null || submission.answers() == null) {
            throw new ResponseStatusException(HttpStatus.UPGRADE_REQUIRED, "Sınav doğrulaması için uygulamayı güncelle");
        }
        if (!catalog.path("version").asText().equals(submission.quizVersion())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Sınav sürümü değişti. Uygulamayı güncelle");
        }
        if (submission.answers().size() != 3) throw new IllegalArgumentException("Tam üç cevap gönderilmelidir");
        int correct = 0;
        for (int i=0;i<3;i++) {
            Integer answer = submission.answers().get(i);
            if (answer == null || answer < 0 || answer >= questions.get(i).path("options").size())
                throw new IllegalArgumentException("Geçersiz sınav cevabı");
            if (answer == questions.get(i).path("correctOptionIndex").asInt()) correct++;
        }
        if (correct < 2) throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Geçmek için en az iki doğru cevap gerekir");
    }
}
