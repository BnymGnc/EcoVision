package com.ecovision.backend.model;

import java.util.Arrays;

public enum AvatarTier {
    LEVEL_1(1, "Çöp Adam", 0),
    LEVEL_2(2, "Fidan İzcisi", 150),
    LEVEL_3(3, "Geri Dönüşüm Çırağı", 300),
    LEVEL_4(4, "Yeşil Kaşif", 450),
    LEVEL_5(5, "Atık Gözcüsü", 600),
    LEVEL_6(6, "Gezegen Yardımcısı", 750),
    LEVEL_7(7, "Eko Maceracı", 900),
    LEVEL_8(8, "Temiz Şehir Korucusu", 1_050),
    LEVEL_9(9, "Doğa Savunucusu", 1_200),
    LEVEL_10(10, "Eko Savaşçı", 1_350),
    LEVEL_11(11, "Döngüsel Yaşam Şampiyonu", 1_500),
    LEVEL_12(12, "Karbon Avcısı", 1_650),
    LEVEL_13(13, "Okyanus Koruyucusu", 1_800),
    LEVEL_14(14, "Orman Muhafızı", 1_950),
    LEVEL_15(15, "İklim Kaptanı", 2_100),
    LEVEL_16(16, "Sıfır Atık Ustası", 2_250),
    LEVEL_17(17, "Dünya Nöbetçisi", 2_400),
    LEVEL_18(18, "Gezegen Muhafızı", 2_550),
    LEVEL_19(19, "Gaia'nın Habercisi", 2_700),
    LEVEL_20(20, "Gaia'nın Seçilmişi", 2_850);

    private final int level;
    private final String title;
    private final int requiredLifetimePoints;

    AvatarTier(int level, String title, int requiredLifetimePoints) {
        this.level = level;
        this.title = title;
        this.requiredLifetimePoints = requiredLifetimePoints;
    }

    public static AvatarTier fromLevel(int level) {
        return Arrays.stream(values())
                .filter(tier -> tier.level == level)
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Avatar seviyesi 1 ile 20 arasında olmalıdır"));
    }

    public static AvatarTier highestUnlocked(int lifetimePoints) {
        return Arrays.stream(values())
                .filter(tier -> tier.requiredLifetimePoints <= lifetimePoints)
                .reduce((first, second) -> second)
                .orElse(LEVEL_1);
    }

    public int level() {
        return level;
    }

    public String title() {
        return title;
    }

    public int requiredLifetimePoints() {
        return requiredLifetimePoints;
    }
}
