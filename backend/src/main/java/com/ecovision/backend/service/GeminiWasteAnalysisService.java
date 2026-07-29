package com.ecovision.backend.service;

import com.ecovision.backend.dto.DetectedWasteResponse;
import com.ecovision.backend.model.WasteMaterial;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class GeminiWasteAnalysisService {
    private static final Logger LOGGER =
            LoggerFactory.getLogger(GeminiWasteAnalysisService.class);
    private static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;
    static final String DEFAULT_MODEL = "gemini-3.6-flash";
    private static final String STABLE_FALLBACK_MODEL = "gemini-3.5-flash";
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
    private final List<String> modelCandidates;

    public GeminiWasteAnalysisService(
            ObjectMapper objectMapper,
            @Value("${GEMINI_API_KEY:}") String apiKey,
            @Value("${gemini.model:gemini-3.6-flash}") String model,
            @Value("${gemini.connect-timeout-ms:5000}") int connectTimeoutMs,
            @Value("${gemini.read-timeout-ms:30000}") int readTimeoutMs
    ) {
        SimpleClientHttpRequestFactory requestFactory =
                new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofMillis(connectTimeoutMs));
        requestFactory.setReadTimeout(Duration.ofMillis(readTimeoutMs));
        this.restClient = RestClient.builder()
                .requestFactory(requestFactory)
                .build();
        this.objectMapper = objectMapper;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.modelCandidates = resolveModelCandidates(model);
    }

    public List<DetectedWasteResponse> analyze(MultipartFile image) {
        validateImage(image);
        long startedAt = System.nanoTime();
        try {
            byte[] imageBytes = image.getBytes();
            Map<String, Object> request = Map.of(
                    "contents", List.of(Map.of(
                            "role", "user",
                            "parts", List.of(
                                    Map.of("text", PROMPT),
                                    Map.of("inlineData", Map.of(
                                            "mimeType", image.getContentType(),
                                            "data", Base64.getEncoder()
                                                    .encodeToString(imageBytes)
                                    ))
                            )
                    )),
                    "generationConfig", Map.of(
                            "temperature", 0.1,
                            "responseMimeType", "application/json",
                            "responseJsonSchema", responseSchema(),
                            "maxOutputTokens", 512
                    )
            );
            ProviderResponse providerResponse =
                    requestAnalysis(request, startedAt);
            JsonNode root = objectMapper.readTree(providerResponse.body());
            JsonNode textNode = root.path("candidates").path(0)
                    .path("content").path("parts").path(0).path("text");
            if (!textNode.isTextual()) {
                String finishReason = root.path("candidates").path(0)
                        .path("finishReason").asText("UNKNOWN");
                throw new IllegalStateException(
                        "Gemini geçerli analiz döndürmedi: " + finishReason
                );
            }
            List<DetectedWasteResponse> detections =
                    parseDetections(textNode.asText());
            LOGGER.info(
                    "Gemini analysis completed: model={}, durationMs={}, detections={}",
                    providerResponse.model(),
                    elapsedMillis(startedAt),
                    detections.size()
            );
            return detections;
        } catch (IllegalArgumentException exception) {
            throw exception;
        } catch (ResourceAccessException exception) {
            LOGGER.warn(
                    "Gemini analysis timed out: model={}, durationMs={}, reason={}",
                    modelCandidates.get(0),
                    elapsedMillis(startedAt),
                    exception.getMostSpecificCause().getClass().getSimpleName()
            );
            throw new ResponseStatusException(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "Görüntü analizi zaman aşımına uğradı. Lütfen tekrar deneyin."
            );
        } catch (RestClientResponseException exception) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    providerErrorMessage(exception)
            );
        } catch (Exception exception) {
            LOGGER.error(
                    "Gemini analysis failed: model={}, durationMs={}, contentType={}, size={}",
                    modelCandidates.get(0),
                    elapsedMillis(startedAt),
                    image.getContentType(),
                    image.getSize(),
                    exception
            );
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "Atık görseli analiz edilemedi. Farklı bir fotoğrafla tekrar deneyin."
            );
        }
    }

    private ProviderResponse requestAnalysis(
            Map<String, Object> request,
            long startedAt
    ) {
        for (int index = 0; index < modelCandidates.size(); index++) {
            String candidate = modelCandidates.get(index);
            try {
                String responseBody = restClient.post()
                        .uri("https://generativelanguage.googleapis.com/v1beta/models/"
                                + candidate + ":generateContent")
                        .header("x-goog-api-key", apiKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(request)
                        .retrieve()
                        .body(String.class);
                return new ProviderResponse(candidate, responseBody);
            } catch (RestClientResponseException exception) {
                LOGGER.error(
                        "Gemini provider error: model={}, durationMs={}, status={}, response={}",
                        candidate,
                        elapsedMillis(startedAt),
                        exception.getStatusCode().value(),
                        safeProviderBody(exception.getResponseBodyAsString())
                );
                boolean canFallback = exception.getStatusCode().value() == 404
                        && index + 1 < modelCandidates.size();
                if (!canFallback) {
                    throw exception;
                }
                LOGGER.warn(
                        "Gemini model {} is unavailable; retrying with {}",
                        candidate,
                        modelCandidates.get(index + 1)
                );
            }
        }
        throw new IllegalStateException("No Gemini model candidate is available");
    }

    static List<String> resolveModelCandidates(String configuredModel) {
        Set<String> candidates = new LinkedHashSet<>();
        String normalized = normalizeModelName(configuredModel);
        if (!normalized.isBlank()) {
            candidates.add(normalized);
        }
        candidates.add(DEFAULT_MODEL);
        candidates.add(STABLE_FALLBACK_MODEL);
        return List.copyOf(candidates);
    }

    private static String normalizeModelName(String model) {
        if (model == null) {
            return "";
        }
        String normalized = model.trim();
        if (normalized.startsWith("models/")) {
            normalized = normalized.substring("models/".length());
        }
        return normalized;
    }

    private Map<String, Object> responseSchema() {
        return Map.of(
                "type", "object",
                "properties", Map.of(
                        "waste_types", Map.of(
                                "type", "array",
                                "items", Map.of(
                                        "type", "object",
                                        "properties", Map.of(
                                                "type", Map.of("type", "string"),
                                                "confidence", Map.of("type", "number")
                                        ),
                                        "required", List.of("type", "confidence")
                                )
                        )
                ),
                "required", List.of("waste_types")
        );
    }

    private List<DetectedWasteResponse> parseDetections(String rawJson)
            throws Exception {
        String cleaned = rawJson.trim()
                .replaceFirst("^```(?:json)?\\s*", "")
                .replaceFirst("\\s*```$", "");
        JsonNode items = objectMapper.readTree(cleaned).path("waste_types");
        if (!items.isArray() || items.isEmpty()) {
            throw new IllegalStateException(
                    "Fotoğrafta tanınabilir atık bulunamadı"
            );
        }

        Map<String, DetectedWasteResponse> unique = new LinkedHashMap<>();
        for (JsonNode item : items) {
            String type = normalizeType(item.path("type").asText());
            double confidence = Math.max(
                    0,
                    Math.min(1, item.path("confidence").asDouble(0))
            );
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
        List<DetectedWasteResponse> detections =
                new ArrayList<>(unique.values());
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
            throw new IllegalArgumentException(
                    "Fotoğraf boyutu 5 MB sınırını aşıyor"
            );
        }
        String contentType = image.getContentType();
        if (contentType == null || !List.of(
                "image/jpeg",
                "image/png",
                "image/webp"
        ).contains(contentType.toLowerCase(Locale.ROOT))) {
            throw new IllegalArgumentException(
                    "Yalnızca JPEG, PNG veya WebP kabul edilir"
            );
        }
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "Görüntü analiz servisi henüz yapılandırılmamış"
            );
        }
    }

    private String providerErrorMessage(RestClientResponseException exception) {
        return switch (exception.getStatusCode().value()) {
            case 400 -> "Gemini isteği geçersiz. Model yapılandırmasını kontrol edin.";
            case 401, 403 ->
                    "Gemini API anahtarı geçersiz veya yetkisiz.";
            case 404 -> "Yapılandırılan Gemini modeli bulunamadı.";
            case 429 -> "Gemini kullanım sınırına ulaşıldı. Biraz sonra deneyin.";
            default -> "Görüntü analiz servisine şu anda ulaşılamıyor.";
        };
    }

    private long elapsedMillis(long startedAt) {
        return (System.nanoTime() - startedAt) / 1_000_000;
    }

    private String safeProviderBody(String body) {
        if (body == null || body.isBlank()) {
            return "<empty>";
        }
        String singleLine = body.replaceAll("[\\r\\n]+", " ").trim();
        return singleLine.substring(0, Math.min(singleLine.length(), 1200));
    }

    private record ProviderResponse(String model, String body) {
    }
}
