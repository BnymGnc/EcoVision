package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ScanAnalysisResponse;
import com.ecovision.backend.dto.ScanAnalysisRequest;
import com.ecovision.backend.dto.DetectedWasteResponse;
import com.ecovision.backend.dto.GeminiScanResponse;
import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.ScanService;
import com.ecovision.backend.service.WasteAnalysisService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/scans")
public class ScanController {
    @PostMapping("/eligibility")
    public com.ecovision.backend.service.PackagingEligibility.Result eligibility(
            @RequestBody com.ecovision.backend.service.PackagingEligibility.Request request) {
        return com.ecovision.backend.service.PackagingEligibility.evaluate(request);
    }
    private final ScanService scanService;
    private final CurrentUserService currentUserService;
    private final WasteAnalysisService geminiService;

    public ScanController(
            ScanService scanService,
            CurrentUserService currentUserService,
            WasteAnalysisService geminiService
    ) {
        this.scanService = scanService;
        this.currentUserService = currentUserService;
        this.geminiService = geminiService;
    }

    @GetMapping
    public List<ScanResponse> scans() {
        return scanService.getScans(currentUserService.currentUser());
    }

    @PostMapping
    public ScanResponse saveScan(@Valid @RequestBody ScanRequest request) {
        return scanService.saveScan(currentUserService.currentUser(), request);
    }

    @PostMapping(value = "/analyze", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public GeminiScanResponse analyze(@RequestPart("image") MultipartFile image) {
        var analysis = geminiService.analyze(image);
        List<DetectedWasteResponse> detections = analysis.detections();
        ScanAnalysisResponse scan = scanService.analyzeAndSave(
                currentUserService.currentUser(),
                new ScanAnalysisRequest(toPrediction(detections.get(0).type())),
                detections.size() == 1 && detections.get(0).confidence() >= 0.65
        );
        return new GeminiScanResponse(detections, scan, scan.updatedUserPoints(), analysis.provider(),
                analysis.modelVersion(), analysis.inferenceMode(), detections.size() > 1
                || detections.get(0).confidence() < 0.65);
    }

    private String toPrediction(String type) {
        return switch (type) {
            case "KAGIT" -> "paper";
            case "ELEKTRONIK" -> "electronics";
            case "ORGANIK" -> "organic";
            case "YAG" -> "oil";
            case "TIBBI" -> "medical";
            default -> type;
        };
    }
}
