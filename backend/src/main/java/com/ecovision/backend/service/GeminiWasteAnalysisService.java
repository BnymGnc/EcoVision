package com.ecovision.backend.service;

import com.ecovision.backend.dto.DetectedWasteResponse;
import com.ecovision.backend.model.WasteMaterial;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
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
    private static final int MAX_PROVIDER_ATTEMPTS = 2;
    private static final int MAX_CACHE_ENTRIES = 64;
    private static final Duration CACHE_TTL = Duration.ofMinutes(10);
    static final String DEFAULT_MODEL = "gemini-3.6-flash";
    private static final String STABLE_FALLBACK_MODEL = "gemini-3.5-flash";
    private static final String COMPATIBILITY_MODEL = "gemini-2.5-flash";
    private static final String LOW_QUOTA_FALLBACK_MODEL =
            "gemini-2.5-flash-lite";
    private static final String PROMPT = """
            Bu fotoğraf bir atık sınıflandırma uygulamasından gönderildi.
            Görünen bütün atık nesnelerini ayrı ayrı ve en iyi tahmininle
            sınıflandır. Ambalaj, şişe, kutu, kapak, pil, kablo, kağıt,
            karton ve organik kalıntıları dikkate al. Nesne görünüyorsa
            waste_types dizisini boş bırakma; emin değilsen DIGER kullan.
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
    private final Map<String, CachedAnalysis> cache = new ConcurrentHashMap<>();

    public GeminiWasteAnalysisService(
            ObjectMapper objectMapper,
            @Value("${GEMINI_API_KEY:}") String apiKey,
            @Value("${gemini.model:gemini-3.6-flash}") String model,
            @Value("${gemini.connect-timeout-ms:10000}") int connectTimeoutMs,
            @Value("${gemini.read-timeout-ms:60000}") int readTimeoutMs
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
            String cacheKey = imageDigest(imageBytes);
            CachedAnalysis cached = cache.get(cacheKey);
            if (cached != null && !cached.expired()) {
                LOGGER.info(
                        "Gemini analysis cache hit: contentType={}, size={}",
                        image.getContentType(),
                        image.getSize()
                );
                return cached.detections();
            }
            if (cached != null) {
                cache.remove(cacheKey);
            }
            String mimeType = canonicalMimeType(image);
            Map<String, Object> request = Map.of(
                    "contents", List.of(Map.of(
                            "role", "user",
                            "parts", List.of(
                                    Map.of("text", PROMPT),
                                    Map.of("inlineData", Map.of(
                                            "mimeType", mimeType,
                                            "data", Base64.getEncoder()
                                                    .encodeToString(imageBytes)
                                    ))
                            )
                    )),
                    "generationConfig", Map.of(
                            "responseMimeType", "application/json",
                            "responseJsonSchema", responseSchema(),
                            "maxOutputTokens", 512
                    )
            );
            ProviderResponse providerResponse =
                    requestAnalysis(request, startedAt);
            JsonNode root = objectMapper.readTree(providerResponse.body());
            String responseText = extractResponseText(root);
            if (responseText == null) {
                String finishReason = root.path("candidates").path(0)
                        .path("finishReason").asText("UNKNOWN");
                throw new IllegalStateException(
                        "Gemini geçerli analiz döndürmedi: " + finishReason
                );
            }
            List<DetectedWasteResponse> detections =
                    parseDetections(responseText);
            cacheResult(cacheKey, detections);
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
        RestClientResponseException lastFailure = null;
        for (int index = 0; index < modelCandidates.size(); index++) {
            String candidate = modelCandidates.get(index);
            for (int attempt = 1; attempt <= MAX_PROVIDER_ATTEMPTS; attempt++) {
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
                    lastFailure = exception;
                    int status = exception.getStatusCode().value();
                    boolean transientFailure = status == 408
                            || status == 429
                            || status >= 500;
                    LOGGER.warn(
                            "Gemini provider error: model={}, attempt={}, durationMs={}, status={}, response={}",
                            candidate,
                            attempt,
                            elapsedMillis(startedAt),
                            status,
                            safeProviderBody(exception.getResponseBodyAsString())
                    );
                    if (transientFailure && attempt < MAX_PROVIDER_ATTEMPTS) {
                        sleepBeforeRetry(attempt);
                        continue;
                    }
                    boolean canFallback = (status == 404 || transientFailure)
                            && index + 1 < modelCandidates.size();
                    if (!canFallback) {
                        throw exception;
                    }
                    LOGGER.warn(
                            "Gemini model {} failed; retrying with {}",
                            candidate,
                            modelCandidates.get(index + 1)
                    );
                    break;
                }
            }
        }
        if (lastFailure != null) {
            throw lastFailure;
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
        candidates.add(COMPATIBILITY_MODEL);
        candidates.add(LOW_QUOTA_FALLBACK_MODEL);
        return List.copyOf(candidates);
    }

    private String extractResponseText(JsonNode root) {
        JsonNode parts = root.path("candidates").path(0)
                .path("content").path("parts");
        if (!parts.isArray()) {
            return null;
        }
        for (JsonNode part : parts) {
            JsonNode text = part.path("text");
            if (text.isTextual() && !text.asText().isBlank()) {
                return text.asText();
            }
        }
        return null;
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
        String contentType = canonicalMimeType(image);
        if (!List.of(
                "image/jpeg",
                "image/png",
                "image/webp",
                "image/heic",
                "image/heif"
        ).contains(contentType)) {
            throw new IllegalArgumentException(
                    "Yalnızca JPEG, PNG, WebP, HEIC veya HEIF kabul edilir"
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
            case 429 -> "Gemini kotası geçici olarak dolu. Otomatik yeniden "
                    + "denemeler tamamlandı; lütfen kısa süre sonra tekrar deneyin.";
            default -> "Görüntü analiz servisine şu anda ulaşılamıyor.";
        };
    }

    private String canonicalMimeType(MultipartFile image) {
        String contentType = image == null ? null : image.getContentType();
        String normalized = contentType == null
                ? ""
                : contentType.toLowerCase(Locale.ROOT).trim();
        if (!normalized.isBlank()
                && !normalized.equals("application/octet-stream")) {
            return normalized;
        }
        String filename = image == null || image.getOriginalFilename() == null
                ? ""
                : image.getOriginalFilename().toLowerCase(Locale.ROOT);
        if (filename.endsWith(".png")) return "image/png";
        if (filename.endsWith(".webp")) return "image/webp";
        if (filename.endsWith(".heic")) return "image/heic";
        if (filename.endsWith(".heif")) return "image/heif";
        return "image/jpeg";
    }

    private void sleepBeforeRetry(int attempt) {
        long delayMillis = 650L * (1L << Math.max(0, attempt - 1))
                + (long) (Math.random() * 300L);
        try {
            Thread.sleep(delayMillis);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                    "Gemini yeniden denemesi kesintiye uğradı",
                    exception
            );
        }
    }

    private String imageDigest(byte[] bytes) {
        try {
            return Base64.getEncoder().encodeToString(
                    MessageDigest.getInstance("SHA-256").digest(bytes)
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 kullanılamıyor", exception);
        }
    }

    private void cacheResult(
            String cacheKey,
            List<DetectedWasteResponse> detections
    ) {
        if (cache.size() >= MAX_CACHE_ENTRIES) {
            cache.keySet().stream().findFirst().ifPresent(cache::remove);
        }
        cache.put(
                cacheKey,
                new CachedAnalysis(List.copyOf(detections), Instant.now())
        );
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

    private record CachedAnalysis(
            List<DetectedWasteResponse> detections,
            Instant createdAt
    ) {
        private boolean expired() {
            return createdAt.plus(CACHE_TTL).isBefore(Instant.now());
        }
    }
}
