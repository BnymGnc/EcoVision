package com.ecovision.backend.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class AvatarTierTest {
    @Test
    void exposesTwentyOrderedProgressionStages() {
        AvatarTier[] tiers = AvatarTier.values();
        assertEquals(20, tiers.length);
        assertEquals("Çöp Adam", tiers[0].title());
        assertEquals("Gaia'nın Seçilmişi", tiers[19].title());
        assertEquals(20, AvatarTier.fromLevel(20).level());
    }

    @Test
    void rejectsLevelsOutsideTheCatalog() {
        assertThrows(IllegalArgumentException.class, () -> AvatarTier.fromLevel(21));
    }
}
