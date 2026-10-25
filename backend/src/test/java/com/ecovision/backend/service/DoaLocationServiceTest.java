package com.ecovision.backend.service;

import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import java.util.List;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class DoaLocationServiceTest {
    final MapPinRepository repository = mock(MapPinRepository.class);
    final ObjectMapper mapper = new ObjectMapper();
    final DoaLocationService service = new DoaLocationService(repository, mapper);
    DoaLocationServiceTest() throws Exception {}

    @Test void all81ProvincesAnd973DistrictsResolveWithTurkishCharacters() throws Exception {
        try (var input = new ClassPathResource("data/turkey_locations.json").getInputStream()) {
            var provinces = mapper.readTree(input).get("provinces");
            assertEquals(81, provinces.size());
            int districts = 0;
            for (var entries = provinces.fields(); entries.hasNext();) {
                var entry = entries.next();
                for (var district : entry.getValue()) {
                    var expected = new DoaLocationService.Area(entry.getKey(), district.asText());
                    assertEquals(expected, service.resolve("No:42 " + entry.getKey() + "/" + district.asText()));
                    assertEquals(expected, service.resolve(district.asText() + "/" + entry.getKey() + ", Türkiye"));
                    districts++;
                }
            }
            assertEquals(973, districts);
        }
    }
    @Test void streetNamedUrfaDoesNotOverrideDiyarbakirAndUnknownIsNotGuessed() {
        assertEquals("Diyarbakır", service.resolve("Urfa Yolu No:12 DİYARBAKIR/KAYAPINAR").city());
        assertEquals("", service.resolve("Konevi belediye C blok").city());
        assertThrows(IllegalArgumentException.class, () -> service.ids("Kayseri", "Haliliye"));
        assertThrows(IllegalArgumentException.class, () -> service.ids(null, "Talas"));
    }
    @Test void inventoryIncludesEmptyProvincesAndUsesSmallCachedProjection() {
        var row = mock(MapPinRepository.LocationSummary.class);
        when(row.getId()).thenReturn(1L); when(row.getAddress()).thenReturn("Kayseri/Talas");
        when(row.getPointType()).thenReturn("DIM"); when(row.getLatitude()).thenReturn(38.7); when(row.getLongitude()).thenReturn(35.5);
        when(repository.findLocationSummaries()).thenReturn(List.of(row));
        assertEquals(81, service.inventory().cities().size());
        assertEquals(1, service.inventory().total());
        assertEquals(Set.of(1L), service.ids("KAYSERI", "TALAS"));
        assertEquals(Set.of(), service.ids("Istanbul", null));
        verify(repository, times(1)).findLocationSummaries();
        verify(repository, never()).findAll();
    }
}
