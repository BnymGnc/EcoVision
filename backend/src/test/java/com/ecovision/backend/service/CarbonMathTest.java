package com.ecovision.backend.service;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CarbonMathTest {
    @Test void electricityUnitAndHouseholdShareMatchHandCalculation() {
        var result = CarbonMath.assess(new CarbonMath.Inputs(200.0, 2, "NONE", null));
        assertEquals(562.8, result.annualKnownKg(), 0.00001);
        assertEquals(46.9, result.monthlyKnownKg(), 0.00001);
        assertFalse(result.missingCategories().isEmpty());
    }
    @Test void missingConsumptionIsNotAssumedZero() {
        assertNull(CarbonMath.assess(new CarbonMath.Inputs(null, 1, null, null)).annualKnownKg());
        assertThrows(IllegalArgumentException.class, () -> CarbonMath.assess(new CarbonMath.Inputs(-1.0, 1, "NONE", null)));
    }
    @Test void warmShortTonConversionPreservesSignsAndUnknownMaterials() {
        assertEquals(1.17 * 1000 / 907.18474, CarbonMath.wasteDifference("pet", 1, "LANDFILL", "RECYCLING"), 0.000001);
        assertEquals(0.0, CarbonMath.wasteDifference("glass", 1, "RECYCLING", "RECYCLING"));
        assertTrue(CarbonMath.wasteDifference("aluminum", 1, "RECYCLING", "LANDFILL") < 0);
        assertNull(CarbonMath.wasteDifference("plastic", 1, "LANDFILL", "RECYCLING"));
    }
}
