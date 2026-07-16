package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.ScanService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/scans")
public class ScanController {
    private final ScanService scanService;
    private final CurrentUserService currentUserService;

    public ScanController(ScanService scanService, CurrentUserService currentUserService) {
        this.scanService = scanService;
        this.currentUserService = currentUserService;
    }

    @GetMapping
    public List<ScanResponse> scans() {
        return scanService.getScans(currentUserService.currentUser());
    }

    @PostMapping
    public ScanResponse saveScan(@Valid @RequestBody ScanRequest request) {
        return scanService.saveScan(currentUserService.currentUser(), request);
    }
}
