package com.ecovision.backend.service;

import java.util.List;

public final class PackagingEligibility {
    public static final String VERSION = "DOA-2026-10-24";
    public static final String SOURCE = "https://doa.gov.tr/hangi-ambalajlar-iade-edilir";
    private PackagingEligibility() {}
    public static Result evaluate(Request request) {
        if (request == null) throw new IllegalArgumentException("Ambalaj bilgileri gereklidir");
        if (request.material() == null || request.material().isBlank()) return result("UNKNOWN", "MATERIAL_CONFIRMATION_REQUIRED");
        if (!List.of("pet", "glass", "aluminum").contains(request.material()))
            return result("INELIGIBLE", "UNSUPPORTED_MATERIAL");
        if (Boolean.FALSE.equals(request.singleUseNonDairyBeverage())
                || Boolean.FALSE.equals(request.doaMark()) || Boolean.FALSE.equals(request.emptyAndIntact()))
            return result("INELIGIBLE", "PACKAGING_RULE_NOT_MET");
        if (request.volumeLitres() != null && (!Double.isFinite(request.volumeLitres())
                || request.volumeLitres() < 0.10 || request.volumeLitres() > 3.01))
            return result("INELIGIBLE", "VOLUME_OUT_OF_SCOPE");
        if (request.singleUseNonDairyBeverage() == null || request.doaMark() == null
                || request.emptyAndIntact() == null || request.volumeLitres() == null)
            return result("UNKNOWN", "USER_CONFIRMATION_REQUIRED");
        return result("ELIGIBLE", "USER_DECLARED_PACKAGING");
    }
    private static Result result(String status, String code) {
        return new Result(status, code.equals("USER_DECLARED_PACKAGING") ? "USER_DECLARED" : "UNKNOWN",
                List.of(code), VERSION, SOURCE);
    }
    public record Request(String material, Boolean singleUseNonDairyBeverage, Boolean doaMark,
                          Boolean emptyAndIntact, Double volumeLitres) {}
    public record Result(String eligibilityStatus, String eligibilityEvidence, List<String> reasonCodes,
                         String ruleVersion, String sourceUrl) {}
}
