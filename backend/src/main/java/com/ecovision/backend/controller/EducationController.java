package com.ecovision.backend.controller;

import com.ecovision.backend.dto.EducationCompletionResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.EducationProgressService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/education")
public class EducationController {
    private final EducationProgressService education;
    private final CurrentUserService currentUser;
    private final com.ecovision.backend.service.EducationQuizCatalog quizzes;

    public EducationController(
            EducationProgressService education,
            CurrentUserService currentUser,
            com.ecovision.backend.service.EducationQuizCatalog quizzes
    ) {
        this.education = education;
        this.currentUser = currentUser;
        this.quizzes = quizzes;
    }

    @GetMapping("/progress")
    public List<String> progress() {
        return education.completedCategoryIds(currentUser.currentUser());
    }

    @PostMapping("/complete/{categoryId}")
    public EducationCompletionResponse complete(
            @PathVariable String categoryId,
            @org.springframework.web.bind.annotation.RequestBody(required = false) com.ecovision.backend.service.EducationQuizCatalog.Submission submission
    ) {
        return education.complete(currentUser.currentUser(), categoryId, submission);
    }
    @GetMapping("/quiz/{categoryId}")
    public java.util.Map<String,Object> quiz(@PathVariable String categoryId) { return quizzes.publicQuiz(categoryId); }
}
