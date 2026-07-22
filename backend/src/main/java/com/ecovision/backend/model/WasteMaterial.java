package com.ecovision.backend.model;

import java.util.Arrays;
import java.util.Locale;

public enum WasteMaterial {
    PLASTIC("Plastik Atık", 10, true, "450 yıl", "yeni şişeler, lifler ve kaplar", "plastic", "plastik", "pet"),
    GLASS("Cam Atık", 12, true, "1 milyon yıl", "yeni kavanozlar, şişeler ve cam elyafı", "glass", "cam"),
    PAPER("Kağıt ve Karton", 8, true, "2-6 hafta", "kağıt havlu, karton ve ambalaj", "paper", "cardboard", "kağıt", "karton"),
    METAL("Metal Atık", 15, true, "80-200 yıl", "yeni kutular, folyo ve yapı malzemeleri", "metal", "aluminum", "alüminyum", "can"),
    ELECTRONICS("Elektronik Atık", 20, true, "20-1000 yıl", "geri kazanılmış metaller ve elektronik parçalar", "electronic", "electronics", "elektronik", "e-waste", "battery", "pil"),
    ORGANIC("Organik Atık", 5, false, "2-8 hafta", "kompost veya biyogaz", "organic", "organik", "bio_waste", "food", "gıda"),
    OIL("Bitkisel Atık Yağ", 12, false, "Özel işlem gerekir", "endüstriyel geri kazanım veya biyodizel", "oil", "yağ"),
    MEDICAL("Tıbbi Atık", 20, false, "Özel işlem gerekir", "lisanslı tıbbi atık bertarafı", "hospital_waste", "medical", "tıbbi"),
    GENERAL("Karışık Atık", 5, false, "Atık türüne göre değişir", "belediye atık ayrıştırma tesisi", "open_litter", "dustbin_waste"),
    UNKNOWN("Bilinmeyen Atık", 0, false, "Bilinmiyor", "uzman atık işleme tesisi");

    private final String displayName;
    private final int points;
    private final boolean recyclable;
    private final String decayYears;
    private final String recycledInto;
    private final String[] keywords;

    WasteMaterial(
            String displayName,
            int points,
            boolean recyclable,
            String decayYears,
            String recycledInto,
            String... keywords
    ) {
        this.displayName = displayName;
        this.points = points;
        this.recyclable = recyclable;
        this.decayYears = decayYears;
        this.recycledInto = recycledInto;
        this.keywords = keywords;
    }

    public static WasteMaterial detect(String prediction) {
        String normalized = prediction == null ? "" : prediction.trim().toLowerCase(Locale.ROOT);
        return Arrays.stream(values())
                .filter(material -> material != UNKNOWN)
                .filter(material -> Arrays.stream(material.keywords)
                        .anyMatch(normalized::contains))
                .findFirst()
                .orElse(UNKNOWN);
    }

    public int points() {
        return points;
    }

    public String displayName() {
        return displayName;
    }

    public boolean recyclable() {
        return recyclable;
    }

    public String decayYears() {
        return decayYears;
    }

    public String recycledInto() {
        return recycledInto;
    }
}
