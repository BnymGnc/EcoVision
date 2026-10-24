package com.ecovision.backend.service;

import com.drew.imaging.ImageMetadataReader;
import com.drew.metadata.exif.ExifIFD0Directory;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;

final class AnalysisImage {
    private AnalysisImage() {}

    static Decoded decode(byte[] bytes) throws Exception {
        BufferedImage image;
        try (var input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
            var readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw new IllegalArgumentException("JPEG veya PNG fotoğraf seç");
            var reader = readers.next();
            try {
                reader.setInput(input);
                if ((long) reader.getWidth(0) * reader.getHeight(0) > 4_000_000)
                    throw new IllegalArgumentException("Fotoğraf çözünürlüğünü küçültüp tekrar dene");
                image = reader.read(0);
            } finally { reader.dispose(); }
        }
        int orientation = 1;
        try {
            var exif = ImageMetadataReader.readMetadata(new ByteArrayInputStream(bytes))
                    .getFirstDirectoryOfType(ExifIFD0Directory.class);
            if (exif != null && exif.containsTag(ExifIFD0Directory.TAG_ORIENTATION))
                orientation = exif.getInt(ExifIFD0Directory.TAG_ORIENTATION);
        } catch (Exception ignored) { /* Metadata is optional; it is never sent to the provider. */ }
        return new Decoded(image, orientation);
    }

    static byte[] cloudJpeg(byte[] bytes) throws Exception {
        var decoded = decode(bytes);
        boolean rotated = decoded.orientation >= 5 && decoded.orientation <= 8;
        int width = rotated ? decoded.image.getHeight() : decoded.image.getWidth();
        int height = rotated ? decoded.image.getWidth() : decoded.image.getHeight();
        double scale = Math.min(1, 1600.0 / Math.max(width, height));
        int outWidth = Math.max(1, (int) (width * scale)), outHeight = Math.max(1, (int) (height * scale));
        BufferedImage clean = new BufferedImage(outWidth, outHeight, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < outHeight; y++) for (int x = 0; x < outWidth; x++) {
            int px = Math.min(width - 1, (int) ((x + 0.5) * width / outWidth));
            int py = Math.min(height - 1, (int) ((y + 0.5) * height / outHeight));
            clean.setRGB(x, y, LocalWasteModel.pixel(decoded.image, px, py, decoded.orientation));
        }
        try (var output = new ByteArrayOutputStream()) {
            if (!ImageIO.write(clean, "jpeg", output)) throw new IllegalStateException("JPEG encoder unavailable");
            return output.toByteArray();
        }
    }

    record Decoded(BufferedImage image, int orientation) {}
}
