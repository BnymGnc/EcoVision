package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinBin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AdminServiceMapFilterTest {
    @Test
    void returnsPinsAcceptingAnySelectedMaterial() {
        MapPinRepository pins = mock(MapPinRepository.class);
        AdminService service = service(pins);
        when(pins.findAll()).thenReturn(List.of(
                pin("PET noktasi", "pet", true),
                pin("Cam noktasi", "glass", true),
                pin("Aluminyum noktasi", "aluminum", true),
                pin("Kapali hazne", "pet", false)
        ));

        var result = service.getNearestMapPins(
                38.72,
                35.48,
                null,
                null,
                Set.of("pet", "glass", "aluminum")
        );

        assertEquals(3, result.size());
    }

    @Test
    void mapsMetalFilterToActiveAluminumBins() {
        MapPinRepository pins = mock(MapPinRepository.class);
        AdminService service = service(pins);
        when(pins.findAll()).thenReturn(List.of(
                pin("Aluminyum noktasi", "aluminum", true),
                pin("PET noktasi", "pet", true)
        ));

        var result = service.getNearestMapPins(
                38.72,
                35.48,
                null,
                null,
                Set.of("metal")
        );

        assertEquals(1, result.size());
        assertEquals("Aluminyum noktasi", result.get(0).title());
    }

    private AdminService service(MapPinRepository pins) {
        ObjectMapper objectMapper = new ObjectMapper();
        RvmCatalogService catalog = new RvmCatalogService(
                mock(AppUserRepository.class),
                pins,
                objectMapper
        ) {
            @Override
            public void ensureCatalogAvailable() {
                // Catalog synchronization is covered by RvmCatalogServiceTest.
            }
        };
        return new AdminService(
                mock(AppUserRepository.class),
                pins,
                new OverpassMapPinService(objectMapper, 1000, 1000),
                catalog
        );
    }

    private MapPin pin(String title, String material, boolean accepting) {
        AppUser owner = new AppUser();
        owner.setName("EcoVision");
        owner.setSurname("Admin");

        MapPin pin = new MapPin();
        pin.setTitle(title);
        pin.setLatitude(38.72);
        pin.setLongitude(35.48);
        pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
        pin.setCreatedBy(owner);
        pin.setActive(true);
        pin.setBinList(List.of(new MapPinBin(material, 10, accepting)));
        return pin;
    }
}
