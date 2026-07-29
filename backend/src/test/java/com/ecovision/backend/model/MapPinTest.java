package com.ecovision.backend.model;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class MapPinTest {
    @Test
    void acceptsMaterialOnlyWhenMatchingBinIsActive() {
        MapPin pin = new MapPin();
        pin.setBinStates(Map.of(
                "pet", true,
                "glass", true,
                "aluminum", false
        ));
        pin.setBinList(List.of(
                new MapPinBin("pet", 45, false),
                new MapPinBin("glass", 20, true),
                new MapPinBin("aluminum", 5, false)
        ));

        assertFalse(pin.acceptsMaterial("pet"));
        assertTrue(pin.acceptsMaterial("cam"));
        assertFalse(pin.acceptsMaterial("aluminum"));
        assertTrue(pin.currentlyAcceptedMaterials().contains("glass"));
        assertFalse(pin.currentlyAcceptedMaterials().contains("pet"));
    }

    @Test
    void emptyBinListNeverAcceptsMaterial() {
        MapPin pin = new MapPin();
        pin.setBinStates(Map.of("pet", true));

        assertFalse(pin.acceptsMaterial("pet"));
        assertTrue(pin.currentlyAcceptedMaterials().isEmpty());
    }
}
