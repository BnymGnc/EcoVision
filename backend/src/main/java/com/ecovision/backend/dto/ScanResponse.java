package com.ecovision.backend.dto;

import com.ecovision.backend.model.ScanHistory;
import java.time.Instant;

public record ScanResponse(
        Long id,
        Long userId,
        String materialType,
        Boolean recyclable,
        String decayYears,
        String recycledInto,
        Integer pointsAwarded,
        Instant scannedAt
) {
    public static ScanResponse from(ScanHistory scan) {
        return new ScanResponse(
                scan.getId(),
                scan.getUser().getId(),
                scan.getMaterialType(),
                scan.getIsRecyclable(),
                scan.getDecayYears(),
                scan.getRecycledInto(),
                scan.getPointsAwarded(),
                scan.getScannedAt()
        );
    }
}
