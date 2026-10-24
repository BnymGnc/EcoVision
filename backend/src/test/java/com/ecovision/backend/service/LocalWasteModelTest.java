package com.ecovision.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mock.web.MockMultipartFile;
import java.awt.image.BufferedImage;
import java.util.HashSet;
import static org.junit.jupiter.api.Assertions.*;

class LocalWasteModelTest {
    @Test void preprocessingHasTheDocumentedRgbNormalizationAndShape() {
        var image = new BufferedImage(2, 2, BufferedImage.TYPE_INT_RGB);
        image.setRGB(0, 0, 0xff0000); image.setRGB(1, 0, 0x00ff00);
        image.setRGB(0, 1, 0x0000ff); image.setRGB(1, 1, 0xffffff);
        float[] tensor = LocalWasteModel.preprocess(image, 1);
        assertEquals(3 * 224 * 224, tensor.length);
        assertEquals((1 - 0.485f) / 0.229f, tensor[0], 0.00001);
        assertEquals((0 - 0.456f) / 0.224f, tensor[224 * 224], 0.00001);
        float[] flipped = LocalWasteModel.preprocess(image, 2);
        assertEquals((0 - 0.485f) / 0.229f, flipped[0], 0.00001);
    }

    @Test void realArtifactMatchesPythonOutputsForSixRealImageFixtures() throws Exception {
        var mapper = new ObjectMapper();
        try (var expected = new ClassPathResource("ml/expected.json").getInputStream()) {
            var model = new LocalWasteModel(mapper, true, "ml/waste-mobilenet-v1.onnx");
            try {
                HashSet<String> observedTypes = new HashSet<>();
                for (var sample : mapper.readTree(expected)) {
                    byte[] bytes;
                    try (var input = new ClassPathResource("ml/" + sample.path("file").asText()).getInputStream()) { bytes = input.readAllBytes(); }
                    try (var input = new java.util.zip.GZIPInputStream(new ClassPathResource("ml/" + sample.path("file").asText() + ".tensor.gz").getInputStream())) {
                        var data = java.nio.ByteBuffer.wrap(input.readAllBytes()).order(java.nio.ByteOrder.LITTLE_ENDIAN).asFloatBuffer();
                        float[] reference = new float[data.remaining()]; data.get(reference);
                        var decoded = javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(bytes));
                        float[] actual = LocalWasteModel.preprocess(decoded, 1);
                        assertArrayEquals(reference, actual, 0.00001f, sample.path("file").asText());
                    }
                    var result = model.analyze(new MockMultipartFile("image", "sample.png", "image/png", bytes)).get(0);
                    String expectedType = switch (sample.path("type").asText()) {
                        case "cardboard", "paper" -> "KAGIT"; case "glass" -> "CAM";
                        case "metal" -> "METAL"; case "plastic" -> "PLASTIK"; default -> "DIGER";
                    };
                    assertEquals(expectedType, result.type());
                    assertEquals(sample.path("score").asDouble(), result.confidence(), 0.0005);
                    observedTypes.add(result.type());
                }
                assertTrue(observedTypes.size() > 1, "Model must respond to different image content");
            } finally { model.close(); }
        }
    }
}
