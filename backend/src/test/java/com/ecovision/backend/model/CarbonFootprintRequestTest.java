package com.ecovision.backend.model;

import static org.junit.jupiter.api.Assertions.*;
import com.ecovision.backend.dto.CarbonFootprintRequest;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;

class CarbonFootprintRequestTest {
    @Test void acceptsConsumptionAdjustedTotalsButStillBoundsInvalidValues() {
        try (var factory = Validation.buildDefaultValidatorFactory()) {
            var validator = factory.getValidator();
            assertTrue(validator.validate(new CarbonFootprintRequest(35000)).isEmpty());
            assertFalse(validator.validate(new CarbonFootprintRequest(-1)).isEmpty());
            assertFalse(validator.validate(new CarbonFootprintRequest(50000001)).isEmpty());
        }
    }
}
