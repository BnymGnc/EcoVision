package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinBin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;

@Configuration(proxyBeanMethods = false)
public class RvmDataLoader {
    static final String DATA_PATH = "data/rvm-machines-additional.json";
    static final String SANLIURFA_DATA_PATH =
            "data/rvm-machines-sanliurfa.json";
    public static final int EXPECTED_MACHINE_COUNT = 144;
    private static final Set<String> SUPPORTED_CONTENT_TYPES =
            Set.of("pet", "glass", "aluminum");
    private static final Logger LOGGER =
            LoggerFactory.getLogger(RvmDataLoader.class);

    @Bean
    @Order(3)
    CommandLineRunner seedRvmMachineCatalog(
            AppUserRepository userRepository,
            MapPinRepository mapPinRepository,
            ObjectMapper objectMapper
    ) {
        return args -> {
            AppUser owner = userRepository.findByEmail("admin@ecovision.com")
                    .orElseThrow(() -> new IllegalStateException(
                            "RVM makineleri için süper kullanıcı bulunamadı"
                    ));
            List<RvmSeed> machines = loadAndValidate(objectMapper);

            Map<String, MapPin> existingByName = new HashMap<>();
            Map<String, MapPin> existingByCoordinates = new HashMap<>();
            for (MapPin existing : mapPinRepository.findAll()) {
                existingByName.putIfAbsent(
                        normalizeName(existing.getTitle()),
                        existing
                );
                existingByCoordinates.putIfAbsent(
                        coordinateKey(
                                existing.getLatitude(),
                                existing.getLongitude()
                        ),
                        existing
                );
            }

            List<MapPin> updates = new ArrayList<>();
            for (RvmSeed machine : machines) {
                MapPin pin = existingByName.get(normalizeName(machine.name()));
                if (pin == null) {
                    pin = existingByCoordinates.get(
                            coordinateKey(
                                    machine.latitude(),
                                    machine.longitude()
                            )
                    );
                }
                if (pin == null) {
                    pin = new MapPin();
                }

                apply(machine, pin, owner);
                if (!updates.contains(pin)) {
                    updates.add(pin);
                }
            }

            mapPinRepository.saveAll(updates);
            LOGGER.info(
                    "RVM kataloğu işlendi: {} kaynak kayıt, {} eklenen/güncellenen kayıt",
                    machines.size(),
                    updates.size()
            );
        };
    }

    public static List<RvmSeed> loadAndValidate(ObjectMapper objectMapper)
            throws Exception {
        ClassPathResource resource = new ClassPathResource(DATA_PATH);
        List<RvmSeed> machines;
        try (InputStream input = resource.getInputStream()) {
            machines = objectMapper.readValue(
                    input,
                    new TypeReference<List<RvmSeed>>() {
                    }
            );
        }

        ClassPathResource sanliurfaResource =
                new ClassPathResource(SANLIURFA_DATA_PATH);
        List<RvmSeed> mergedMachines = new ArrayList<>(machines);
        try (InputStream input = sanliurfaResource.getInputStream()) {
            mergedMachines.addAll(objectMapper.readValue(
                    input,
                    new TypeReference<List<RvmSeed>>() {
                    }
            ));
        }
        machines = mergedMachines;

        if (machines.size() != EXPECTED_MACHINE_COUNT) {
            throw new IllegalStateException(
                    "RVM veri seti " + EXPECTED_MACHINE_COUNT
                            + " kayıt içermelidir; bulunan: " + machines.size()
            );
        }

        Set<String> names = new HashSet<>();
        for (RvmSeed machine : machines) {
            validateMachine(machine, names);
        }
        return List.copyOf(machines);
    }

    private static void validateMachine(
            RvmSeed machine,
            Set<String> names
    ) {
        if (machine.name() == null || machine.name().isBlank()
                || machine.address() == null || machine.address().isBlank()
                || machine.latitude() < 35.0 || machine.latitude() > 43.0
                || machine.longitude() < 25.0
                || machine.longitude() > 46.0
                || machine.binList() == null
                || machine.binList().isEmpty()) {
            throw new IllegalStateException(
                    "Geçersiz RVM kaydı: " + machine.name()
            );
        }
        if (!names.add(normalizeName(machine.name()))) {
            throw new IllegalStateException(
                    "RVM veri setinde yinelenen makine adı: " + machine.name()
            );
        }

        Set<String> contentTypes = new HashSet<>();
        for (RvmBinSeed bin : machine.binList()) {
            if (bin.contentType() == null || bin.contentType().isBlank()
                    || bin.level() < 0
                    || !SUPPORTED_CONTENT_TYPES.contains(bin.contentType())) {
                throw new IllegalStateException(
                        "Geçersiz RVM kutu kaydı: " + machine.name()
                );
            }
            if (!contentTypes.add(bin.contentType())) {
                throw new IllegalStateException(
                        "Yinelenen RVM kutu türü: " + machine.name()
                                + "/" + bin.contentType()
                );
            }
        }
        if (!contentTypes.equals(SUPPORTED_CONTENT_TYPES)) {
            throw new IllegalStateException(
                    "Eksik RVM kutu türü: " + machine.name()
            );
        }
    }

    public static void apply(
            RvmSeed machine,
            MapPin pin,
            AppUser owner
    ) {
        Map<String, Boolean> binStates = new LinkedHashMap<>();
        List<MapPinBin> binList = new ArrayList<>();
        for (RvmBinSeed bin : machine.binList()) {
            binStates.put(bin.contentType(), bin.state());
            binList.add(new MapPinBin(
                    bin.contentType(),
                    bin.level(),
                    bin.state()
            ));
        }

        pin.setTitle(machine.name().trim());
        pin.setLatitude(machine.latitude());
        pin.setLongitude(machine.longitude());
        pin.setAddress(machine.address().trim());
        pin.setBinList(binList);
        pin.setBinStates(binStates);
        pin.setAcceptedMaterials(
                binStates.entrySet().stream()
                        .filter(entry -> Boolean.TRUE.equals(entry.getValue()))
                        .map(Map.Entry::getKey)
                        .collect(java.util.stream.Collectors.toSet())
        );
        pin.setActive(true);
        pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
        if (pin.getCreatedBy() == null) {
            pin.setCreatedBy(owner);
        }
    }

    public static String normalizeName(String name) {
        return name.trim().toLowerCase(Locale.ROOT);
    }

    public static String coordinateKey(double latitude, double longitude) {
        return Double.toString(latitude) + "|" + Double.toString(longitude);
    }

    public record RvmSeed(
            String name,
            double latitude,
            double longitude,
            String address,
            List<RvmBinSeed> binList
    ) {
    }

    public record RvmBinSeed(
            String contentType,
            int level,
            boolean state
    ) {
    }
}
