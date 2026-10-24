package com.ecovision.backend.controller;

import com.ecovision.backend.model.MediaAsset;
import com.ecovision.backend.repository.MediaAssetRepository;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/media")
public class MediaController {
    private final MediaAssetRepository mediaAssets;
    private final com.ecovision.backend.service.MediaAccessService access;

    public MediaController(MediaAssetRepository mediaAssets, com.ecovision.backend.service.MediaAccessService access) {
        this.mediaAssets = mediaAssets;
        this.access = access;
    }

    @GetMapping("/{id}")
    public ResponseEntity<byte[]> get(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "false") boolean download,
            @org.springframework.security.core.annotation.AuthenticationPrincipal com.ecovision.backend.model.AppUser viewer
    ) {
        var descriptor = mediaAssets.describe(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Medya bulunamadı"));
        access.requireAccess(id, descriptor.getCategory(), descriptor.getOwnerUserId(), viewer);
        MediaAsset asset = mediaAssets.findById(id)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Medya bulunamadı"
                ));
        MediaType contentType;
        try {
            contentType = MediaType.parseMediaType(asset.getContentType());
        } catch (IllegalArgumentException ignored) {
            contentType = MediaType.APPLICATION_OCTET_STREAM;
        }
        ContentDisposition disposition = (download || contentType.equals(MediaType.APPLICATION_PDF)
                ? ContentDisposition.attachment()
                : ContentDisposition.inline())
                .filename(asset.getOriginalFileName(), StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .contentType(contentType)
                .contentLength(asset.getSizeBytes())
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store, max-age=0")
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .body(asset.getData());
    }
}
