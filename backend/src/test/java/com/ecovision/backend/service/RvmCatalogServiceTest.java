package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class RvmCatalogServiceTest {
    @Test
    void seedsAllMachinesWhenCatalogIsMissing() {
        AppUserRepository users = mock(AppUserRepository.class);
        MapPinRepository pins = mock(MapPinRepository.class);
        AppUser owner = new AppUser();
        when(users.findByEmail("admin@ecovision.com"))
                .thenReturn(Optional.of(owner));
        when(pins.findAll()).thenReturn(List.of());

        RvmCatalogService service = new RvmCatalogService(
                users,
                pins,
                new ObjectMapper()
        );
        service.ensureCatalogAvailable();

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<MapPin>> captor =
                ArgumentCaptor.forClass(List.class);
        verify(pins).saveAllAndFlush(captor.capture());
        assertEquals(130, captor.getValue().size());
    }

    @Test
    void skipsUpsertWhenOfficialCatalogIsAlreadyPresent() {
        AppUserRepository users = mock(AppUserRepository.class);
        MapPinRepository pins = mock(MapPinRepository.class);
        when(pins.countByType(MapPinType.OFFICIAL_RECYCLING_BIN))
                .thenReturn(130L);

        RvmCatalogService service = new RvmCatalogService(
                users,
                pins,
                new ObjectMapper()
        );
        service.ensureCatalogAvailable();

        verify(pins, never()).findAll();
        verify(pins, never()).saveAllAndFlush(org.mockito.ArgumentMatchers.any());
    }
}
