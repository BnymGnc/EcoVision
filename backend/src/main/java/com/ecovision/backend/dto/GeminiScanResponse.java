package com.ecovision.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public record GeminiScanResponse(
        List<DetectedWasteResponse> detections,
        ScanAnalysisResponse scan,
        @JsonProperty("updated_user_points")
        int updatedUserPoints
) {
}
