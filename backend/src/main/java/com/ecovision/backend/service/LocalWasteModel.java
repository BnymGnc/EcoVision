package com.ecovision.backend.service;

import ai.onnxruntime.*;
import com.ecovision.backend.dto.DetectedWasteResponse;
import com.ecovision.backend.model.WasteMaterial;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.FloatBuffer;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.Semaphore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class LocalWasteModel {
    private final OrtSession session;
    private final OrtEnvironment environment;
    private final String inputName;
    private final String version;
    private final List<String> labels;
    private final Semaphore permits = new Semaphore(1);

    public LocalWasteModel(ObjectMapper mapper, @Value("${ml.enabled:false}") boolean enabled,
                           @Value("${ml.model-path:ml/waste-mobilenet-v1.onnx}") String modelPath) throws Exception {
        if (!enabled) { session = null; environment = null; inputName = null; version = "disabled"; labels = List.of(); return; }
        byte[] bytes;
        try (var stream = new ClassPathResource(modelPath).getInputStream()) { bytes = stream.readAllBytes(); }
        try (var stream = new ClassPathResource("ml/model-metadata.json").getInputStream()) {
            var metadata = mapper.readTree(stream);
            String actual = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
            if (!actual.equals(metadata.path("sha256").asText())) throw new IllegalStateException("Local model checksum mismatch");
            inputName = metadata.path("input_name").asText(); version = metadata.path("version").asText();
            List<String> values = new ArrayList<>(); metadata.path("labels").forEach(value -> values.add(value.asText()));
            labels = List.copyOf(values);
        }
        environment = OrtEnvironment.getEnvironment();
        try (var options = new OrtSession.SessionOptions()) {
            options.setIntraOpNumThreads(2); options.setInterOpNumThreads(1);
            options.setCPUArenaAllocator(false);
            options.setMemoryPatternOptimization(false);
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT);
            session = environment.createSession(bytes, options);
        }
    }

    public String version() { return version; }
    public List<DetectedWasteResponse> analyze(MultipartFile image) {
        if (session == null) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Yerel görsel model etkin değil");
        if (image == null || image.isEmpty() || image.getSize() > 5L * 1024 * 1024)
            throw new IllegalArgumentException("Geçerli, en fazla 5 MB bir fotoğraf seç");
        if (!permits.tryAcquire()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Görsel analiz meşgul. Kısa süre sonra tekrar dene.");
        try {
            byte[] bytes = image.getBytes();
            var decoded = AnalysisImage.decode(bytes);
            float[] inputData = preprocess(decoded.image(), decoded.orientation());
            try (var tensor = OnnxTensor.createTensor(environment, FloatBuffer.wrap(inputData), new long[]{1, 3, 224, 224});
                 var output = session.run(Map.of(inputName, tensor))) {
                float[] scores = ((float[][])output.get(0).getValue())[0];
                int best = 0;
                for (int i = 1; i < scores.length; i++) if (scores[i] > scores[best]) best = i;
                String type = switch (labels.get(best)) {
                    case "cardboard", "paper" -> "KAGIT";
                    case "glass" -> "CAM";
                    case "metal" -> "METAL";
                    case "plastic" -> "PLASTIK";
                    default -> "DIGER";
                };
                WasteMaterial material = WasteMaterial.detect(switch (type) {
                    case "KAGIT" -> "paper"; case "PLASTIK" -> "plastic"; default -> type;
                });
                boolean candidate = Set.of("CAM", "PLASTIK", "METAL").contains(type);
                return List.of(new DetectedWasteResponse(type, material.displayName(), scores[best], candidate,
                        candidate ? "Ambalaj uygunluğunu kontrol et" : "DOA kapsamı dışında veya belirsiz"));
            }
        } catch (IllegalArgumentException | ResponseStatusException failure) { throw failure; }
        catch (Exception failure) { throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Yerel görsel analiz tamamlanamadı"); }
        finally { permits.release(); }
    }

    static float[] preprocess(BufferedImage source, int orientation) {
        // Explicit half-pixel mapping is shared with ml/train.py.
        boolean rotated = orientation >= 5 && orientation <= 8;
        int width = rotated ? source.getHeight() : source.getWidth();
        int height = rotated ? source.getWidth() : source.getHeight();
        float[] values = new float[3 * 224 * 224];
        float[] means = {0.485f, 0.456f, 0.406f}, std = {0.229f, 0.224f, 0.225f};
        for (int y = 0; y < 224; y++) for (int x = 0; x < 224; x++) {
            int px = Math.min(width - 1, (int)((x + 0.5) * width / 224));
            int py = Math.min(height - 1, (int)((y + 0.5) * height / 224));
            int rgb = pixel(source, px, py, orientation);
            for (int c = 0; c < 3; c++) {
                int shift = (2 - c) * 8;
                float value = ((rgb >> shift) & 255) / 255.0f;
                values[c * 224 * 224 + y * 224 + x] = (value - means[c]) / std[c];
            }
        }
        return values;
    }
    static int pixel(BufferedImage image, int x, int y, int orientation) {
        int w = image.getWidth(), h = image.getHeight();
        return switch (orientation) {
            case 2 -> image.getRGB(w - 1 - x, y); case 3 -> image.getRGB(w - 1 - x, h - 1 - y);
            case 4 -> image.getRGB(x, h - 1 - y); case 5 -> image.getRGB(y, x);
            case 6 -> image.getRGB(y, h - 1 - x); case 7 -> image.getRGB(w - 1 - y, h - 1 - x);
            case 8 -> image.getRGB(w - 1 - y, x); default -> image.getRGB(x, y);
        };
    }
    @PreDestroy public void close() throws OrtException { if (session != null) session.close(); }
}
