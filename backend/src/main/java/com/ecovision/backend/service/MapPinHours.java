package com.ecovision.backend.service;

import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

public final class MapPinHours {
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm");

    private MapPinHours() {
    }

    public static boolean isOpenNow(String workingHours) {
        if (workingHours == null || !workingHours.matches("\\d{2}:\\d{2} - \\d{2}:\\d{2}")) {
            return false;
        }
        String[] parts = workingHours.split(" - ");
        LocalTime now = LocalTime.now(ZoneId.of("Europe/Istanbul"));
        LocalTime opens = LocalTime.parse(parts[0], TIME);
        LocalTime closes = LocalTime.parse(parts[1], TIME);
        return !now.isBefore(opens) && !now.isAfter(closes);
    }
}
