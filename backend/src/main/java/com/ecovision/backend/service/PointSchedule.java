package com.ecovision.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.*;
import java.util.List;
import java.util.Locale;

public final class PointSchedule {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final List<String> DAYS = List.of("pazartesi", "salı", "çarşamba", "perşembe", "cuma", "cumartesi", "pazar");
    private PointSchedule() {}

    public static String status(String json, Instant now) {
        try {
            JsonNode days = MAPPER.readTree(json == null ? "[]" : json);
            ZonedDateTime local = now.atZone(ZONE);
            int today = local.getDayOfWeek().getValue() - 1;
            LocalTime time = local.toLocalTime();
            boolean knownToday = false;
            for (JsonNode day : days) {
                String name = day.path("day").asText("").toLowerCase(Locale.forLanguageTag("tr"));
                int index = DAYS.indexOf(name);
                if (index < 0) continue;
                if (index == today && day.path("closed").asBoolean(false)) {
                    knownToday = true;
                    continue;
                }
                if (index == today && day.path("allDay").asBoolean(false)) return "OPEN";
                if (day.path("startTime").isMissingNode() || day.path("startTime").isNull()
                        || day.path("endTime").isMissingNode() || day.path("endTime").isNull()) continue;
                LocalTime start = LocalTime.parse(day.path("startTime").asText());
                String endText = day.path("endTime").asText();
                boolean untilMidnight = endText.startsWith("24:00");
                LocalTime end = untilMidnight ? LocalTime.MIDNIGHT : LocalTime.parse(endText);
                boolean overnight = day.path("overnight").asBoolean(false) || end.isBefore(start);
                boolean allDay = day.path("allDay").asBoolean(false) || start.equals(LocalTime.MIDNIGHT) && untilMidnight;
                if (index == today) {
                    knownToday = true;
                    if (allDay || !time.isBefore(start) && (overnight || untilMidnight || time.isBefore(end))) return "OPEN";
                }
                if (index == (today + 6) % 7 && overnight && !untilMidnight && time.isBefore(end)) return "OPEN";
            }
            return knownToday ? "CLOSED" : "UNKNOWN";
        } catch (Exception ignored) {
            return "UNKNOWN";
        }
    }
}
