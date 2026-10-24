package com.ecovision.backend.service;

import java.util.*;

public final class CarbonMath {
    public static final String VERSION = "ETKB2023-EPA2015-v1";
    public static final String ELECTRICITY_SOURCE = "https://enerji.gov.tr/evced-cevre-ve-iklim-elektrik-uretim-tuketim-emisyon-faktorleri";
    public static final String FUEL_SOURCE = "https://www.epa.gov/greenvehicles/greenhouse-gas-emissions-typical-passenger-vehicle";
    public static final String WARM_SOURCE = "https://archive.epa.gov/epawaste/conserve/tools/warm/Warm_Form.html";
    private CarbonMath() {}

    public static Assessment assess(Inputs input) {
        if (input.householdMembers() < 1 || input.householdMembers() > 50)
            throw new IllegalArgumentException("Hane kişi sayısı 1-50 olmalıdır");
        List<String> missing = new ArrayList<>();
        Map<String, Double> annual = new LinkedHashMap<>();
        if (input.monthlyElectricityKwh() == null) missing.add("Elektrik tüketimi");
        else {
            nonnegative(input.monthlyElectricityKwh());
            annual.put("electricity", input.monthlyElectricityKwh() * 12 * 0.469 / input.householdMembers());
        }
        if ("NONE".equals(input.fuelType())) annual.put("vehicleFuel", 0.0);
        else if (input.monthlyFuelLitres() == null) missing.add("Araç yakıt tüketimi");
        else {
            nonnegative(input.monthlyFuelLitres());
            double kgPerLitre = switch (input.fuelType() == null ? "" : input.fuelType()) {
                case "PETROL" -> 8.887 / 3.785411784;
                case "DIESEL" -> 10.180 / 3.785411784;
                default -> throw new IllegalArgumentException("Yakıt türü benzin veya dizel olmalıdır");
            };
            annual.put("vehicleFuel", input.monthlyFuelLitres() * 12 * kgPerLitre);
        }
        missing.addAll(List.of("Isınma", "Beslenme", "Uçuşlar", "Diğer tüketim"));
        Double total = annual.isEmpty() ? null : annual.values().stream().mapToDouble(Double::doubleValue).sum();
        return new Assessment(total, total == null ? null : total / 12, annual, missing, VERSION,
                "Kısmi tahmin: elektrik CO2e ve araç yanma CO2. Tam kişisel envanter değildir.",
                List.of(new Factor("electricity", 0.469, "kgCO2e/kWh", 2023, "Türkiye dağıtım şebekesi", ELECTRICITY_SOURCE),
                        new Factor("petrol", 8.887 / 3.785411784, "kgCO2/litre", 2015, "ABD yakıtı, Türkiye için vekil", FUEL_SOURCE),
                        new Factor("diesel", 10.180 / 3.785411784, "kgCO2/litre", 2015, "ABD yakıtı, Türkiye için vekil", FUEL_SOURCE)));
    }

    public static Double wasteDifference(String material, double massKg, String baseline, String selected) {
        nonnegative(massKg);
        Double recycling = switch (material == null ? "" : material) {
            case "pet" -> -1.13;
            case "glass" -> -0.28;
            case "aluminum" -> -9.11;
            default -> null;
        };
        if (recycling == null || !Set.of("LANDFILL", "RECYCLING").contains(baseline)
                || !Set.of("LANDFILL", "RECYCLING").contains(selected)) return null;
        double from = baseline.equals("LANDFILL") ? 0.04 : recycling;
        double to = selected.equals("LANDFILL") ? 0.04 : recycling;
        // EPA WARM v13: metric tonnes CO2e / US short ton of material.
        return massKg * (from - to) * 1000 / 907.18474;
    }

    private static void nonnegative(double value) {
        if (!Double.isFinite(value) || value < 0 || value > 1_000_000)
            throw new IllegalArgumentException("Tüketim negatif olamaz ve geçerli bir sayı olmalıdır");
    }
    public record Inputs(Double monthlyElectricityKwh, int householdMembers, String fuelType, Double monthlyFuelLitres) {}
    public record Factor(String id, double value, String unit, int year, String geography, String sourceUrl) {}
    public record Assessment(Double annualKnownKg, Double monthlyKnownKg, Map<String, Double> annualByCategory,
                             List<String> missingCategories, String factorVersion, String scope, List<Factor> factors) {}
}
