package com.ecovision.backend.service;

import com.ecovision.backend.dto.DetectedWasteResponse;
import com.ecovision.backend.model.WasteMaterial;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class GeminiWasteAnalysisService {
    private static final Logger LOGGER =
            LoggerFactory.getLogger(GeminiWasteAnalysisService.class);
    private static final long MAX_IMAGE_BYTES = 8L * 1024 * 1024;
    private static final String PROMPT = """
            Görseldeki bütün atık nesnelerini ayrı ayrı sınıflandır.
            Yalnızca şu JSON şemasına uyan bir nesne döndür:
            {"waste_types":[{"type":"PET","confidence":0.95}]}
            type yalnızca PET, CAM, ALUMINUM, KAGIT, METAL, ELEKTRONIK,
            ORGANIK, YAG, TIBBI veya DIGER değerlerinden biri olabilir.
            confidence 0 ile 1 arasında sayıdır. Markdown ve açıklama ekleme.
            """;

    private final RestClient restClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    public GeminiWasteAnalysisService(
            ObjectMapper objectMapper,
            @Value("${gemini.api.key}") String apiKey,
            @Value("${gemini.model:gemini-2.5-flash}") String model
    ) {
        this.restClient = RestClient.create();
        this.objectMapper = objectMapper;
        this.apiKey = apiKey;
        this.model = model;
    }

    public List<DetectedWasteResponse> analyze(MultipartFile image) {
        validateImage(image);
        try {
            Map<String, Object> request = Map.of(
                    "contents", List.of(Map.of(
                            "parts", List.of(
                                    Map.of("text", PROMPT),
                                    Map.of("inlineData", Map.of(
                                            "mimeType", image.getContentType(),
                                            "data", Base64.getEncoder()
                                                    .encodeToString(image.getBytes())
                                    ))
                            )
                    )),
                    "generationConfig", Map.of(
                            "temperature", 0.1,
                            "responseMimeType", "application/json",
                            "maxOutputTokens", 1024
                    )
            );
            String responseBody = restClient.post()
                    .uri("https://generativelanguage.googleapis.com/v1beta/models/"
                            + model + ":generateContent")
                    .header("x-goog-api-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .body(String.class);
            JsonNode textNode = objectMapper.readTree(responseBody)
                    .path("candidates").path(0)
                    .path("content").path("parts").path(0).path("text");
            if (!textNode.isTextual()) {
                throw new IllegalStateException("Gemini geçerli bir analiz döndürmedi");
            }
            return parseDetections(textNode.asText());
        } catch (IllegalArgumentException exception) {
            throw exception;
        } catch (RestClientResponseException exception) {
            LOGGER.error(
                    "Gemini analysis failed: model={}, status={}, response={}",
                    model,
                    exception.getStatusCode().value(),
                    safeProviderBody(exception.getResponseBodyAsString())
            );
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "Görüntü analiz servisine şu anda ulaşılamıyor"
            );
        } catch (Exception exception) {
            LOGGER.error(
                    "Gemini analysis failed: model={}, fileName={}, contentType={}, size={}",
                    model,
                    image.getOriginalFilename(),
                    image.getContentType(),
                    image.getSize(),
                    exception
            );
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "Atık görseli analiz edilemedi. Lütfen farklı bir fotoğrafla tekrar deneyin."
            );
        }
    }

    private List<DetectedWasteResponse> parseDetections(String rawJson) throws Exception {
        String cleaned = rawJson.trim()
                .replaceFirst("^```(?:json)?\\s*", "")
                .replaceFirst("\\s*```$", "");
        JsonNode items = objectMapper.readTree(cleaned).path("waste_types");
        if (!items.isArray() || items.isEmpty()) {
            throw new IllegalStateException("Fotoğrafta tanınabilir atık bulunamadı");
        }

        Map<String, DetectedWasteResponse> unique = new LinkedHashMap<>();
        for (JsonNode item : items) {
            String type = normalizeType(item.path("type").asText());
            double confidence = Math.max(0, Math.min(1, item.path("confidence").asDouble(0)));
            WasteMaterial material = WasteMaterial.detect(toPrediction(type));
            boolean eligible = type.equals("PET") || type.equals("ALUMINUM");
            DetectedWasteResponse detection = new DetectedWasteResponse(
                    type,
                    material.displayName(),
                    confidence,
                    eligible,
                    eligible ? "Uygun" : "Uygun değil"
            );
            DetectedWasteResponse previous = unique.get(type);
            if (previous == null || previous.confidence() < confidence) {
                unique.put(type, detection);
            }
        }
        List<DetectedWasteResponse> detections = new ArrayList<>(unique.values());
        detections.sort((left, right) ->
                Double.compare(right.confidence(), left.confidence()));
        return List.copyOf(detections);
    }

    private String normalizeType(String value) {
        String normalized = value == null
                ? "DIGER"
                : value.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "PLASTIC", "PLASTIK", "PLASTİK", "PET ŞİŞE" -> "PET";
            case "GLASS" -> "CAM";
            case "ALUMINIUM", "ALÜMİNYUM", "ALUMINYUM" -> "ALUMINUM";
            case "PAPER", "CARD", "CARDBOARD", "KAĞIT" -> "KAGIT";
            case "E-WASTE", "E_ATIK", "E-ATIK" -> "ELEKTRONIK";
            case "ORGANIC" -> "ORGANIK";
            case "OIL", "ATIK YAG", "ATIK YAĞ" -> "YAG";
            case "MEDICAL", "TEHLIKELI", "TEHLİKELİ" -> "TIBBI";
            default -> normalized;
        };
    }

    private String toPrediction(String type) {
        return switch (type) {
            case "KAGIT" -> "paper";
            case "ELEKTRONIK" -> "electronics";
            case "ORGANIK" -> "organic";
            case "YAG" -> "oil";
            case "TIBBI" -> "medical";
            default -> type;
        };
    }

    private void validateImage(MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new IllegalArgumentException("Atık fotoğrafı zorunludur");
        }
        if (image.getSize() > MAX_IMAGE_BYTES) {
            throw new IllegalArgumentException("Fotoğraf boyutu 8 MB sınırını aşıyor");
        }
        String contentType = image.getContentType();
        if (contentType == null || !List.of(
                "image/jpeg",
                "image/png",
                "image/webp"
        ).contains(contentType.toLowerCase(Locale.ROOT))) {
            throw new IllegalArgumentException("Yalnızca JPEG, PNG veya WebP kabul edilir");
        }
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("Gemini servisi yapılandırılmamış");
        }
    }

    private String safeProviderBody(String body) {
        if (body == null || body.isBlank()) {
            return "<empty>";
        }
        String singleLine = body.replaceAll("[\\r\\n]+", " ").trim();
        return singleLine.substring(0, Math.min(singleLine.length(), 1200));
    }
}
