package com.ecovision.backend.model;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class WasteMaterialTest {
    @Test
    void mapsEveryEmbeddedModelLabelToServerSideCatalog() {
        assertEquals(WasteMaterial.GENERAL, WasteMaterial.detect("open_litter"));
        assertEquals(WasteMaterial.GENERAL, WasteMaterial.detect("dustbin_waste"));
        assertEquals(WasteMaterial.PLASTIC, WasteMaterial.detect("plastic_waste"));
        assertEquals(WasteMaterial.ORGANIC, WasteMaterial.detect("bio_waste"));
        assertEquals(WasteMaterial.MEDICAL, WasteMaterial.detect("hospital_waste"));
    }
}
