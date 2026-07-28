package com.ecovision.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class RvmDataLoaderTest {
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void parsesAllMachinesAndPreservesEveryBinValue() throws Exception {
        List<RvmDataLoader.RvmSeed> machines =
                RvmDataLoader.loadAndValidate(objectMapper);

        assertEquals(130, machines.size());
        assertEquals(
                390,
                machines.stream().mapToInt(machine -> machine.binList().size()).sum()
        );
        assertEquals(
                130,
                machines.stream()
                        .map(RvmDataLoader.RvmSeed::name)
                        .collect(java.util.stream.Collectors.toSet())
                        .size()
        );

        var first = machines.get(0);
        assertEquals("A101 H896 HASAN GAZİ", first.name());
        assertEquals(3, first.binList().size());
        assertEquals("pet", first.binList().get(0).contentType());
        assertEquals(100, first.binList().get(0).level());
        assertFalse(first.binList().get(0).state());

        var levelAboveOneHundred = machines.stream()
                .flatMap(machine -> machine.binList().stream())
                .filter(bin -> bin.level() == 130)
                .findFirst()
                .orElseThrow();
        assertEquals("pet", levelAboveOneHundred.contentType());
        assertFalse(levelAboveOneHundred.state());

        machines.forEach(machine -> {
            Set<String> types = new HashSet<>();
            machine.binList().forEach(bin -> types.add(bin.contentType()));
            assertEquals(Set.of("pet", "glass", "aluminum"), types);
            assertFalse(hasMojibake(machine.name()));
            assertFalse(hasMojibake(machine.address()));
        });
    }

    @Test
    void upsertsByNameThenCoordinatesWithoutDeletingExistingRows()
            throws Exception {
        RvmDataLoader loader = new RvmDataLoader();
        AppUserRepository users = mock(AppUserRepository.class);
        MapPinRepository pins = mock(MapPinRepository.class);
        AppUser owner = new AppUser();
        List<RvmDataLoader.RvmSeed> catalog =
                RvmDataLoader.loadAndValidate(objectMapper);

        MapPin nameMatch = existingPin(
                catalog.get(0).name(),
                40.0,
                30.0,
                owner
        );
        MapPin coordinateMatch = existingPin(
                "Eski makine adı",
                catalog.get(1).latitude(),
                catalog.get(1).longitude(),
                owner
        );

        when(users.findByEmail("admin@ecovision.com"))
                .thenReturn(Optional.of(owner));
        when(pins.findAll()).thenReturn(List.of(nameMatch, coordinateMatch));

        loader.seedRvmMachineCatalog(users, pins, objectMapper).run();

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Iterable<MapPin>> captor =
                ArgumentCaptor.forClass(Iterable.class);
        verify(pins).saveAll(captor.capture());
        List<MapPin> saved = new ArrayList<>();
        captor.getValue().forEach(saved::add);

        assertEquals(130, saved.size());
        assertSame(nameMatch, saved.get(0));
        assertSame(coordinateMatch, saved.get(1));
        assertEquals(catalog.get(0).latitude(), nameMatch.getLatitude());
        assertEquals(catalog.get(1).name(), coordinateMatch.getTitle());
        assertEquals(3, nameMatch.getBinList().size());
        assertEquals(100, nameMatch.getBinList().get(0).getLevel());
        assertFalse(nameMatch.getBinList().get(0).isState());
        verify(pins, never()).deleteAll();
        verify(pins, never()).deleteAllInBatch();
        verify(pins, never()).deleteAll(any(Iterable.class));
    }

    private MapPin existingPin(
            String title,
            double latitude,
            double longitude,
            AppUser owner
    ) {
        MapPin pin = new MapPin();
        pin.setTitle(title);
        pin.setLatitude(latitude);
        pin.setLongitude(longitude);
        pin.setCreatedBy(owner);
        return pin;
    }

    private boolean hasMojibake(String value) {
        return value.contains("Ã")
                || value.contains("Ä")
                || value.contains("Å")
                || value.contains("\uFFFD");
    }
}
