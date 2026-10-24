package com.ecovision.backend.config;

import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RvmDataLoaderTest {
    private final ObjectMapper mapper = new ObjectMapper();
    @Test void readsFullSnapshotWithStableIdsAndTypes() throws Exception {
        var catalog = RvmDataLoader.loadCatalog(mapper);
        assertEquals(4037, catalog.points().size());
        assertEquals(0, catalog.quarantineIds().size());
        assertEquals(2162, catalog.points().stream().filter(p -> p.pointType().equals("DIM")).count());
        assertEquals(1764, catalog.points().stream().filter(p -> p.pointType().equals("MIN")).count());
        assertEquals(111, catalog.points().stream().filter(p -> p.pointType().equals("SDM")).count());
        assertEquals(4037, catalog.points().stream().map(RvmDataLoader.RvmSeed::externalId).distinct().count());
        assertEquals(64, catalog.hash().length());
        assertTrue(catalog.points().stream().anyMatch(p -> p.address().contains("ŞANLIURFA")));
    }
    @Test void preservesRawValuesAndIgnoresClusters() throws Exception {
        var source = mapper.readTree("""
            {"rvmList":[{"name":"A","latitude":37.1,"longitude":38.8,"address":"B",
            "binList":[{"contentType":"pet","level":130,"state":false}]}],
            "clusterDataList":[{"latitude":38,"longitude":39}]}
            """);
        var catalog = RvmDataLoader.parse(source, mapper, "hash", Instant.EPOCH, "source");
        assertEquals(1, catalog.points().size());
        var seed = catalog.points().get(0);
        assertEquals(130, seed.binList().get(0).level());
        assertFalse(seed.binList().get(0).state());
        assertTrue(seed.dataQualityFlags().contains("BIN_LEVEL_OUT_OF_RANGE"));
        MapPin pin = new MapPin();
        RvmDataLoader.apply(seed, pin, null);
        assertEquals(130, pin.getBinList().get(0).getLevel());
        assertNull(pin.getTelemetryObservedAt());
        assertNull(pin.getSourceActiveRaw());
    }
    @Test void simplifiedSourceDoesNotInventTelemetry() throws Exception {
        var catalog = RvmDataLoader.parse(mapper.readTree("""
            [{"id":"test-id","name":"Merkez","point_type":"min","latitude":38.1,
            "longitude":35.2,"accepted_materials":["can","pet"],"weekly_schedule":[]}]
            """), mapper, "hash", Instant.EPOCH, "source");
        var seed = catalog.points().get(0);
        assertEquals("MIN", seed.pointType());
        assertFalse(seed.acceptedMaterials().contains("aluminum"));
        assertTrue(seed.binList().isEmpty());
    }
    @Test void dryRunDoesNotWriteAndMatchingHashSkipsImport() throws Exception {
        var catalog = RvmDataLoader.loadCatalog(mapper);
        var users = mock(AppUserRepository.class);
        var pins = mock(MapPinRepository.class);
        when(pins.findCatalogIdentities()).thenReturn(List.of());
        assertEquals(4037, RvmDataLoader.importCatalog(catalog, users, pins, true).inserted());
        verify(pins, never()).saveAll(any());
        when(pins.countByProviderAndDatasetHash("DOA", catalog.hash())).thenReturn(4037L);
        assertEquals(4037, RvmDataLoader.importCatalog(catalog, users, pins, false).unchanged());
        verifyNoInteractions(users);
        verify(pins, never()).deleteAll();
    }
    @Test void invalidCoordinatesAreQuarantined() throws Exception {
        var catalog = RvmDataLoader.parse(mapper.readTree("""
            [{"id":"invalid","name":"X","latitude":999,"longitude":30}]
            """), mapper, "hash", Instant.EPOCH, "source");
        assertTrue(catalog.points().isEmpty());
        assertEquals(List.of("invalid"), catalog.quarantineIds());
    }
}
