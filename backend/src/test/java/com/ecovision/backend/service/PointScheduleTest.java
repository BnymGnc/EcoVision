package com.ecovision.backend.service;

import org.junit.jupiter.api.Test;
import java.time.Instant;
import static org.junit.jupiter.api.Assertions.assertEquals;

class PointScheduleTest {
    @Test void missingTimesAreUnknown() {
        assertEquals("UNKNOWN", PointSchedule.status("[{\"day\":\"Pazartesi\",\"startTime\":null,\"endTime\":null}]",
                Instant.parse("2026-10-26T10:00:00Z")));
    }
    @Test void handlesPreviousDayOvernightAndIstanbulBoundary() {
        String schedule = "[{\"day\":\"Pazartesi\",\"startTime\":\"22:00\",\"endTime\":\"02:00\",\"overnight\":true}]";
        assertEquals("OPEN", PointSchedule.status(schedule, Instant.parse("2026-10-26T22:00:00Z")));
        assertEquals("CLOSED", PointSchedule.status(schedule, Instant.parse("2026-10-26T15:00:00Z")));
        assertEquals("UNKNOWN", PointSchedule.status(schedule, Instant.parse("2026-10-27T00:00:00Z")));
    }
    @Test void recognizesExplicitClosedAndAllDay() {
        assertEquals("CLOSED", PointSchedule.status("[{\"day\":\"Pazartesi\",\"closed\":true}]", Instant.parse("2026-10-26T10:00:00Z")));
        assertEquals("OPEN", PointSchedule.status("[{\"day\":\"Pazartesi\",\"startTime\":\"00:00\",\"endTime\":\"24:00\"}]", Instant.parse("2026-10-26T10:00:00Z")));
    }
}
