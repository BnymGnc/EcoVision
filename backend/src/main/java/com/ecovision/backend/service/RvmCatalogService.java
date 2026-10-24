package com.ecovision.backend.service;

import com.ecovision.backend.config.RvmDataLoader;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

@Service
public class RvmCatalogService {
    private final AppUserRepository users;
    private final MapPinRepository pins;
    private final ObjectMapper mapper;

    public RvmCatalogService(AppUserRepository users, MapPinRepository pins, ObjectMapper mapper) {
        this.users = users;
        this.pins = pins;
        this.mapper = mapper;
    }

    public void ensureCatalogAvailable() {
        // Startup owns imports. Map requests must never parse/import the snapshot.
    }

    public synchronized void synchronizeCatalog() {
        try {
            var catalog = RvmDataLoader.loadCatalog(mapper);
            RvmDataLoader.importCatalog(catalog, users, pins, true);
            RvmDataLoader.importCatalog(catalog, users, pins, false);
        } catch (Exception exception) {
            throw new IllegalStateException("DOA catalog could not be synchronized", exception);
        }
    }
}
