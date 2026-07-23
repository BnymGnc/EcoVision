package com.ecovision.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class QuestDataLoaderTest {
    @Test
    void catalogContainsAllSeventyFiveUniqueTurkishQuests() {
        var catalog = QuestDataLoader.catalog();

        assertEquals(75, catalog.size());
        assertEquals(
                75,
                catalog.stream()
                        .map(QuestDataLoader.QuestSeed::code)
                        .collect(java.util.stream.Collectors.toSet())
                        .size()
        );

        Set<String> titles = new HashSet<>();
        catalog.forEach(seed -> {
            assertTrue(titles.add(seed.title()));
            assertTrue(seed.rewardPoints() > 0);
            assertTrue(seed.targetAmount() > 0);
            assertTrue(seed.title().matches(".*[A-Za-zÇĞİÖŞÜçğıöşü].*"));
            assertTrue(!seed.criteria().isEmpty());
        });

        assertTrue(titles.contains("Sabah Kahvesi"));
        assertTrue(titles.contains("Dünya'nın Kahramanı"));
        assertTrue(titles.contains("Sürdürülebilir Kahraman"));
    }
}
