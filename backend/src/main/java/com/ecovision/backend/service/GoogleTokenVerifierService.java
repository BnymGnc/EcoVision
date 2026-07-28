package com.ecovision.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;

@Service
public class GoogleTokenVerifierService {
    private static final URI TOKEN_INFO_ENDPOINT =
            URI.create("https://oauth2.googleapis.com/tokeninfo");

    private final String clientId;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public GoogleTokenVerifierService(
            @Value("${app.google.client-id:}") String clientId,
            ObjectMapper objectMapper
    ) {
        this.clientId = clientId == null ? "" : clientId.trim();
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
    }

    public VerifiedGoogleIdentity verify(String idToken) {
        if (clientId.isBlank() || clientId.startsWith("dummy-")) {
            throw new IllegalStateException("Google girişi henüz yapılandırılmadı");
        }

        String encodedToken = URLEncoder.encode(idToken, StandardCharsets.UTF_8);
        HttpRequest request = HttpRequest.newBuilder(
                        URI.create(TOKEN_INFO_ENDPOINT + "?id_token=" + encodedToken)
                )
                .timeout(Duration.ofSeconds(8))
                .header("Accept", "application/json")
                .GET()
                .build();

        try {
            HttpResponse<String> response =
                    httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new BadCredentialsException("Google kimliği doğrulanamadı");
            }
            JsonNode claims = objectMapper.readTree(response.body());
            if (!clientId.equals(claims.path("aud").asText())
                    || !claims.path("email_verified").asBoolean(false)
                    || claims.path("sub").asText().isBlank()
                    || claims.path("email").asText().isBlank()) {
                throw new BadCredentialsException("Google kimliği doğrulanamadı");
            }
            return new VerifiedGoogleIdentity(
                    claims.path("sub").asText(),
                    claims.path("email").asText().trim().toLowerCase(),
                    claims.path("given_name").asText("Google"),
                    claims.path("family_name").asText("Kullanıcı"),
                    claims.path("picture").asText(null)
            );
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Google doğrulama servisine ulaşılamadı");
        } catch (IOException exception) {
            throw new IllegalStateException("Google doğrulama servisine ulaşılamadı");
        }
    }

    public record VerifiedGoogleIdentity(
            String subject,
            String email,
            String givenName,
            String familyName,
            String pictureUrl
    ) {
    }
}
