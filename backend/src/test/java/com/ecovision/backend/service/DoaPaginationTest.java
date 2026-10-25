package com.ecovision.backend.service;

import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class DoaPaginationTest {
    @Test void stablePagesIncludeEveryMatchingPointWithoutChangingScheduleOrMaterialSemantics() {
        var repository = mock(MapPinRepository.class);
        List<MapPinRepository.PointSummary> rows = new ArrayList<>();
        for (long id = 1; id <= 230; id++) {
            var row = mock(MapPinRepository.PointSummary.class);
            when(row.getId()).thenReturn(id); when(row.getPointType()).thenReturn("DIM");
            when(row.getLatitude()).thenReturn(38.7); when(row.getLongitude()).thenReturn(35.5);
            when(row.getRawBinsJson()).thenReturn("[{\"contentType\":\"pet\",\"state\":false}]");
            rows.add(row);
        }
        when(repository.findPointSummaries(anyDouble(), anyDouble(), anyDouble(), anyDouble())).thenReturn(rows);
        when(repository.findPointSummariesByIds(anyDouble(), anyDouble(), anyDouble(), anyDouble(), anySet())).thenReturn(rows);
        var service = new DoaMapService(repository, new ObjectMapper());
        Set<Long> ids = new HashSet<>();
        for (int offset = 0; offset < 230; offset += 100) {
            var page = service.search(38.7, 35.5, 10.0, 100, offset, Set.of("pet", "glass"), Set.of("DIM"), false, null, null, null, null, null);
            assertEquals(230, page.total()); assertEquals(offset < 200, page.hasMore());
            page.items().forEach(p -> { assertTrue(ids.add(p.id())); assertEquals("UNKNOWN", p.scheduleStatus()); assertFalse(p.binStates().get("pet")); });
        }
        assertEquals(230, ids.size());
        var cityPage = service.search(38.7, 35.5, null, 100, 0, Set.of(), Set.of(), false, null, null, null, null, Set.of(3L, 8L));
        assertEquals(2, cityPage.total());
        assertThrows(IllegalArgumentException.class, () -> service.search(38.7, 35.5, null, 100, -1, Set.of(), Set.of(), false, null, null, null, null, null));
    }
}
