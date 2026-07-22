package com.ecovision.backend.dto;

import com.ecovision.backend.model.ScanHistory;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Instant;

public record ScanAnalysisResponse(
        Long id,
        String material,
        @JsonProperty("is_recyclable")
        Boolean isRecyclable,
        @JsonProperty("decay_years")
        String decayYears,
        @JsonProperty("recycled_into")
        String recycledInto,
        Instant scannedAt,
        @JsonProperty("points_awarded")
        Integer pointsAwarded,
        @JsonProperty("updated_user_points")
        Integer updatedUserPoints
) {
    public static ScanAnalysisResponse from(ScanHistory scan) {
        return new ScanAnalysisResponse(
                scan.getId(),
                scan.getMaterialType(),
                scan.getIsRecyclable(),
                scan.getDecayYears(),
                scan.getRecycledInto(),
                scan.getScannedAt(),
                scan.getPointsAwarded(),
                scan.getUser().getTotalPoints()
        );
    }
}
