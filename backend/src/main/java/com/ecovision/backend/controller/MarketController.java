package com.ecovision.backend.controller;

import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.MarketService;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/market")
public class MarketController {
    private final MarketService marketService;
    private final CurrentUserService currentUserService;

    public MarketController(
            MarketService marketService,
            CurrentUserService currentUserService
    ) {
        this.marketService = marketService;
        this.currentUserService = currentUserService;
    }

    @PostMapping("/purchase/{itemId}")
    public UserResponse purchase(@PathVariable String itemId) {
        return marketService.purchase(currentUserService.currentUser(), itemId);
    }
}
