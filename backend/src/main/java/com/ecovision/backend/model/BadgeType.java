package com.ecovision.backend.model;

public enum BadgeType {
    STREAK_7("7 Günlük Seri", "Yedi gün boyunca her gün en az bir atık tara"),
    STREAK_30("30 Günlük Efsane", "Otuz günlük tarama serisine ulaş"),
    PLASTIC_HUNTER("Plastik Avcısı", "50 plastik atık tara"),
    GLASS_GUARDIAN("Cam Muhafızı", "50 cam atık tara"),
    PHENOMENON("Fenomen", "Profilinde 50 beğeni kazan");

    private final String title;
    private final String description;

    BadgeType(String title, String description) {
        this.title = title;
        this.description = description;
    }

    public String title() {
        return title;
    }

    public String description() {
        return description;
    }
}
