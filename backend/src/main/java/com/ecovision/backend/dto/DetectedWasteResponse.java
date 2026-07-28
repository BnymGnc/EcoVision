package com.ecovision.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record DetectedWasteResponse(
        String type,
        String material,
        double confidence,
        @JsonProperty("machine_eligible")
        boolean machineEligible,
        @JsonProperty("eligibility_label")
        String eligibilityLabel
) {
}
