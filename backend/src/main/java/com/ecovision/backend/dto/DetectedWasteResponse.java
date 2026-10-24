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
    public String getEligibilityStatus() { return machineEligible ? "UNKNOWN" : "INELIGIBLE"; }
    public String getEligibilityEvidence() { return "UNKNOWN"; }
    public String getMaterialClass() { return type; }
    public String getObjectKind() { return "UNKNOWN"; }
    public boolean isNeedsConfirmation() { return machineEligible || confidence < 0.65; }
    public String getScoreMeaning() { return "MODEL_SELF_REPORTED_NOT_CALIBRATED"; }
}
