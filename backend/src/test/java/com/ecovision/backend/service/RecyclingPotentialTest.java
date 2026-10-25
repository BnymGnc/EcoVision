package com.ecovision.backend.service;

import com.ecovision.backend.repository.ScanHistoryRepository.RecyclingCount;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RecyclingPotentialTest {
    static RecyclingCount count(String material, long count) {
        return new RecyclingCount() {
            public String getMaterial() { return material; }
            public long getScanCount() { return count; }
        };
    }

    @Test void emptySummaryIsZeroNotAnInventedMeasuredSaving() {
        var result = RecyclingPotential.estimate(List.of());
        assertEquals(0, result.recyclableScanCount());
        assertEquals(0, result.potentialKgCo2e());
        assertEquals("ILLUSTRATIVE_SCAN_SCENARIO", result.evidence());
    }

    @Test void usesMassAndMaterialNotPointsAndDoesNotGuessGenericPlasticOrMetal() {
        var result = RecyclingPotential.estimate(List.of(count("pet", 2), count("Cam Atık", 3),
                count("aluminum", 4), count("Plastik Atık", 5), count("Metal Atık", 6), count("Kağıt ve Karton", 7)));
        assertEquals(27, result.recyclableScanCount());
        assertEquals(9, result.modeledScanCount());
        assertEquals(18, result.unmodeledScanCount());
        double expected = CarbonMath.wasteDifference("pet", 0.05, "LANDFILL", "RECYCLING")
                + CarbonMath.wasteDifference("glass", 0.6, "LANDFILL", "RECYCLING")
                + CarbonMath.wasteDifference("aluminum", 0.06, "LANDFILL", "RECYCLING");
        assertEquals(expected, result.potentialKgCo2e(), 1e-12);
        assertNull(RecyclingPotential.materialKey("metal"));
        assertNull(RecyclingPotential.materialKey("plastic"));
        assertEquals("pet", RecyclingPotential.materialKey("PET"));
    }
}
