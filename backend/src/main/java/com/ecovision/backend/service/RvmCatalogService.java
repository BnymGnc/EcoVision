package com.ecovision.backend.service;

import com.ecovision.backend.config.RvmDataLoader;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class RvmCatalogService {
    private static final String SANLIURFA_CATALOG_SENTINEL =
            "MİGROS MJET ŞANLIURFA POLDEM";
    private static final Logger LOGGER =
            LoggerFactory.getLogger(RvmCatalogService.class);

    private final AppUserRepository userRepository;
    private final MapPinRepository mapPinRepository;
    private final ObjectMapper objectMapper;
    private volatile boolean synchronizedForCurrentProcess;

    public RvmCatalogService(
            AppUserRepository userRepository,
            MapPinRepository mapPinRepository,
            ObjectMapper objectMapper
    ) {
        this.userRepository = userRepository;
        this.mapPinRepository = mapPinRepository;
        this.objectMapper = objectMapper;
    }

    public void ensureCatalogAvailable() {
        if (synchronizedForCurrentProcess) {
            return;
        }
        if (mapPinRepository.countByType(
                MapPinType.OFFICIAL_RECYCLING_BIN
        ) >= RvmDataLoader.EXPECTED_MACHINE_COUNT
                && mapPinRepository.findFirstByTitleIgnoreCase(
                        SANLIURFA_CATALOG_SENTINEL
                ).isPresent()) {
            synchronizedForCurrentProcess = true;
            return;
        }
        synchronizeCatalog();
    }

    public synchronized void synchronizeCatalog() {
        if (synchronizedForCurrentProcess) {
            return;
        }

        try {
            AppUser owner = userRepository.findByEmail("admin@ecovision.com")
                    .orElseThrow(() -> new IllegalStateException(
                            "RVM catalog owner could not be found"
                    ));
            List<RvmDataLoader.RvmSeed> machines =
                    RvmDataLoader.loadAndValidate(objectMapper);

            Map<String, MapPin> existingByName = new HashMap<>();
            Map<String, MapPin> existingByCoordinates = new HashMap<>();
            for (MapPin existing : mapPinRepository.findAll()) {
                existingByName.putIfAbsent(
                        RvmDataLoader.normalizeName(existing.getTitle()),
                        existing
                );
                existingByCoordinates.putIfAbsent(
                        RvmDataLoader.coordinateKey(
                                existing.getLatitude(),
                                existing.getLongitude()
                        ),
                        existing
                );
            }

            List<MapPin> updates = new ArrayList<>();
            for (RvmDataLoader.RvmSeed machine : machines) {
                MapPin pin = existingByName.get(
                        RvmDataLoader.normalizeName(machine.name())
                );
                if (pin == null) {
                    pin = existingByCoordinates.get(
                            RvmDataLoader.coordinateKey(
                                    machine.latitude(),
                                    machine.longitude()
                            )
                    );
                }
                if (pin == null) {
                    pin = new MapPin();
                }

                RvmDataLoader.apply(machine, pin, owner);
                if (!updates.contains(pin)) {
                    updates.add(pin);
                }
            }

            mapPinRepository.saveAllAndFlush(updates);
            synchronizedForCurrentProcess = true;
            LOGGER.info(
                    "RVM catalog synchronized: {} source records, {} persisted records",
                    machines.size(),
                    updates.size()
            );
        } catch (Exception exception) {
            synchronizedForCurrentProcess = false;
            throw new IllegalStateException(
                    "RVM catalog could not be synchronized",
                    exception
            );
        }
    }
}
