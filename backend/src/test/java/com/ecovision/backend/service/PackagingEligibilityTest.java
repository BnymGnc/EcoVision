package com.ecovision.backend.service;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class PackagingEligibilityTest {
    @Test void plasticAndMetalDoNotImplyPetOrAluminum() {
        for (String material : new String[]{"plastic", "metal", "paper", "battery"})
            assertEquals("INELIGIBLE", PackagingEligibility.evaluate(new PackagingEligibility.Request(material, true, true, true, 0.5)).eligibilityStatus());
    }
    @Test void requiresAllUserDeclarationsAndNeverClaimsExternalVerification() {
        assertEquals("UNKNOWN", PackagingEligibility.evaluate(new PackagingEligibility.Request("pet", true, null, true, 0.5)).eligibilityStatus());
        var result = PackagingEligibility.evaluate(new PackagingEligibility.Request("glass", true, true, true, 0.5));
        assertEquals("ELIGIBLE", result.eligibilityStatus());
        assertEquals("USER_DECLARED", result.eligibilityEvidence());
        assertEquals("INELIGIBLE", PackagingEligibility.evaluate(new PackagingEligibility.Request("glass", false, true, true, 0.5)).eligibilityStatus());
        assertEquals("INELIGIBLE", PackagingEligibility.evaluate(new PackagingEligibility.Request("pet", true, true, true, 4.0)).eligibilityStatus());
    }
}
