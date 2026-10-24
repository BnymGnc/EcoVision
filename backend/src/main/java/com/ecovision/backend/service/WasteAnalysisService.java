package com.ecovision.backend.service;

import com.ecovision.backend.dto.DetectedWasteResponse;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class WasteAnalysisService {
    private final GeminiWasteAnalysisService gemini;
    private final LocalWasteModel local;
    private final String provider;
    private final boolean allowGeminiOnUncertain;
    public WasteAnalysisService(GeminiWasteAnalysisService gemini, LocalWasteModel local,
            @Value("${ai.provider:gemini}") String provider,
            @Value("${ai.gemini-on-uncertain:false}") boolean allowGeminiOnUncertain) {
        if (!List.of("gemini", "local").contains(provider)) throw new IllegalArgumentException("AI_PROVIDER must be gemini or local");
        this.gemini = gemini; this.local = local; this.provider = provider; this.allowGeminiOnUncertain = allowGeminiOnUncertain;
    }
    public Analysis analyze(MultipartFile image) {
        if (provider.equals("gemini")) return cloud(image);
        var detections = local.analyze(image);
        if (allowGeminiOnUncertain && detections.get(0).confidence() < 0.65) return cloud(image);
        return new Analysis(detections, "ONNX_CPU", local.version(), "LOCAL");
    }
    private Analysis cloud(MultipartFile image) {
        var result = gemini.analyzeDetailed(image);
        return new Analysis(result.detections(), "GEMINI", result.model(), result.cacheHit() ? "CACHE" : "CLOUD");
    }
    public record Analysis(List<DetectedWasteResponse> detections, String provider, String modelVersion, String inferenceMode) {}
}
