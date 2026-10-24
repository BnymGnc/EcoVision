package com.ecovision.backend.service;

import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import static org.mockito.Mockito.*;

class RvmCatalogServiceTest {
    @Test void mapRequestNeverImportsData() {
        var users = mock(AppUserRepository.class);
        var pins = mock(MapPinRepository.class);
        new RvmCatalogService(users, pins, new ObjectMapper()).ensureCatalogAvailable();
        verifyNoInteractions(users, pins);
    }
}
