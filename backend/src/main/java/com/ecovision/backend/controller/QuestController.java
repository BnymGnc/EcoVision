package com.ecovision.backend.controller;

import com.ecovision.backend.dto.QuestClaimResponse;
import com.ecovision.backend.dto.QuestProgressResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.QuestCatalogService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/quests")
public class QuestController {
    private final QuestCatalogService questCatalogService;
    private final CurrentUserService currentUserService;

    public QuestController(
            QuestCatalogService questCatalogService,
            CurrentUserService currentUserService
    ) {
        this.questCatalogService = questCatalogService;
        this.currentUserService = currentUserService;
    }

    @GetMapping
    public List<QuestProgressResponse> catalog(
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "0") int offset,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "200") int limit,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "") String query,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "") String domain
    ) {
        if (offset < 0 || limit < 1 || limit > 200) throw new IllegalArgumentException("Görev sayfa sınırı 1-200 olmalıdır");
        String normalized = query.toLowerCase(java.util.Locale.forLanguageTag("tr"));
        return questCatalogService.catalog(currentUserService.currentUser()).stream()
                .filter(q -> domain.isBlank() || domain.equals(q.domain()))
                .filter(q -> normalized.isBlank() || (q.title() + " " + q.description()).toLowerCase(java.util.Locale.forLanguageTag("tr")).contains(normalized))
                .skip(offset).limit(limit).toList();
    }

    @PostMapping("/{questId}/check-in")
    public QuestProgressResponse checkIn(@PathVariable Long questId) {
        return questCatalogService.checkIn(
                currentUserService.currentUser(),
                questId
        );
    }

    @PostMapping("/progress/{progressId}/claim")
    public QuestClaimResponse claim(@PathVariable Long progressId) {
        return questCatalogService.claim(
                currentUserService.currentUser(),
                progressId
        );
    }
}
