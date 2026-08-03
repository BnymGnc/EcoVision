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

    public MediaController(MediaAssetRepository mediaAssets) {
        this.mediaAssets = mediaAssets;
    }

    @GetMapping("/{id}")
    public ResponseEntity<byte[]> get(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "false") boolean download
    ) {
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
        ContentDisposition disposition = (download
                ? ContentDisposition.attachment()
                : ContentDisposition.inline())
                .filename(asset.getOriginalFileName(), StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .contentType(contentType)
                .contentLength(asset.getSizeBytes())
                .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable())
                .eTag('"' + id.toString() + '"')
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .body(asset.getData());
    }
}
