package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import com.drew.imaging.ImageMetadataReader;
import com.drew.metadata.exif.GpsDirectory;
import java.awt.image.BufferedImage;
import java.io.*;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;

class AnalysisImageTest {
    @Test void reencodesBoundedRgbWithoutGps() throws Exception {
        var original = new BufferedImage(2000, 1000, BufferedImage.TYPE_INT_RGB);
        var encoded = new ByteArrayOutputStream();
        ImageIO.write(original, "png", encoded);
        byte[] clean = AnalysisImage.cloudJpeg(encoded.toByteArray());
        var result = ImageIO.read(new ByteArrayInputStream(clean));
        assertEquals(1600, result.getWidth());
        assertEquals(800, result.getHeight());
        assertNull(ImageMetadataReader.readMetadata(new ByteArrayInputStream(clean)).getFirstDirectoryOfType(GpsDirectory.class));
    }
    @Test void rejectsInvalidImages() {
        assertThrows(IllegalArgumentException.class, () -> AnalysisImage.cloudJpeg("not an image".getBytes()));
    }
}
