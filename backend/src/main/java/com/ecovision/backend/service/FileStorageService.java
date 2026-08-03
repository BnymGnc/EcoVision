package com.ecovision.backend.service;

import java.io.IOException;
import com.ecovision.backend.model.MediaAsset;
import com.ecovision.backend.repository.MediaAssetRepository;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class FileStorageService {
    private static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;
    private static final long MAX_CHAT_BYTES = 2L * 1024 * 1024;
    private static final Set<String> IMAGE_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp"
    );

    private static final String MEDIA_PATH = "/api/media/";

    private final MediaAssetRepository mediaAssets;

    public FileStorageService(MediaAssetRepository mediaAssets) {
        this.mediaAssets = mediaAssets;
    }

    public String storeImage(MultipartFile file, String folder) {
        return storeValidated(file, folder, MAX_IMAGE_BYTES, false);
    }

    public String store(MultipartFile file, String folder) {
        return storeValidated(file, folder, MAX_CHAT_BYTES, true);
    }

    public String replaceImage(MultipartFile file, String folder, String currentUrl) {
        String replacement = storeImage(file, folder);
        if (replacement != null) {
            deleteManaged(currentUrl);
        }
        return replacement;
    }

    private String storeValidated(
            MultipartFile file,
            String folder,
            long maximumBytes,
            boolean allowPdf
    ) {
        if (file == null || file.isEmpty()) {
            return null;
        }
        if (file.getSize() > maximumBytes) {
            throw new IllegalArgumentException("Dosya boyutu izin verilen sınırı aşıyor");
        }
        if (!folder.matches("[a-z0-9_-]{1,30}")) {
            throw new IllegalArgumentException("Geçersiz yükleme klasörü");
        }

        try {
            byte[] bytes = file.getBytes();
            DetectedFile detected = detect(bytes);
            boolean allowed = IMAGE_TYPES.contains(detected.contentType())
                    || (allowPdf && detected.contentType().equals("application/pdf"));
            if (!allowed) {
                throw new IllegalArgumentException(
                        allowPdf
                                ? "Yalnızca JPEG, PNG, WebP veya PDF yüklenebilir"
                                : "Yalnızca JPEG, PNG veya WebP yüklenebilir"
                );
            }

            String declaredType = file.getContentType() == null
                    ? ""
                    : file.getContentType().toLowerCase(Locale.ROOT);
            if (!declaredType.isBlank() && !declaredType.equals(detected.contentType())) {
                throw new IllegalArgumentException("Dosya içeriği ve türü uyuşmuyor");
            }

            MediaAsset asset = new MediaAsset();
            asset.setId(UUID.randomUUID());
            asset.setCategory(folder);
            asset.setContentType(detected.contentType());
            asset.setOriginalFileName(safeFileName(
                    file.getOriginalFilename(),
                    detected.extension()
            ));
            asset.setSizeBytes(bytes.length);
            asset.setData(bytes);
            return MEDIA_PATH + mediaAssets.save(asset).getId();
        } catch (IOException exception) {
            throw new IllegalStateException("Yüklenen dosya kaydedilemedi", exception);
        }
    }

    private void deleteManaged(String url) {
        UUID id = managedId(url);
        if (id != null) {
            mediaAssets.deleteById(id);
        }
    }

    private UUID managedId(String url) {
        if (url == null || url.isBlank()) return null;
        int marker = url.indexOf(MEDIA_PATH);
        if (marker < 0) return null;
        String value = url.substring(marker + MEDIA_PATH.length()).split("[?#/]", 2)[0];
        try {
            return UUID.fromString(value);
        } catch (IllegalArgumentException ignored) {
            return null;
        }
    }

    private String safeFileName(String original, String extension) {
        String candidate = original == null ? "ecovision-media" + extension : original;
        candidate = candidate.replaceAll("[\\r\\n\\\\/]", "_").trim();
        if (candidate.isBlank()) candidate = "ecovision-media" + extension;
        return candidate.length() <= 200 ? candidate : candidate.substring(candidate.length() - 200);
    }

    private DetectedFile detect(byte[] bytes) {
        if (bytes.length >= 3
                && (bytes[0] & 0xFF) == 0xFF
                && (bytes[1] & 0xFF) == 0xD8
                && (bytes[2] & 0xFF) == 0xFF) {
            return new DetectedFile("image/jpeg", ".jpg");
        }
        if (bytes.length >= 8
                && (bytes[0] & 0xFF) == 0x89
                && bytes[1] == 0x50
                && bytes[2] == 0x4E
                && bytes[3] == 0x47) {
            return new DetectedFile("image/png", ".png");
        }
        if (bytes.length >= 12
                && new String(bytes, 0, 4, java.nio.charset.StandardCharsets.US_ASCII)
                .equals("RIFF")
                && new String(bytes, 8, 4, java.nio.charset.StandardCharsets.US_ASCII)
                .equals("WEBP")) {
            return new DetectedFile("image/webp", ".webp");
        }
        if (bytes.length >= 5
                && new String(bytes, 0, 5, java.nio.charset.StandardCharsets.US_ASCII)
                .equals("%PDF-")) {
            return new DetectedFile("application/pdf", ".pdf");
        }
        throw new IllegalArgumentException("Dosya biçimi doğrulanamadı");
    }

    private record DetectedFile(String contentType, String extension) {
    }
}
