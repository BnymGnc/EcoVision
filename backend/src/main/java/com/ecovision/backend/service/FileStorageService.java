package com.ecovision.backend.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class FileStorageService {
    private static final Logger LOGGER =
            LoggerFactory.getLogger(FileStorageService.class);
    private static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;
    private static final long MAX_CHAT_BYTES = 2L * 1024 * 1024;
    private static final Set<String> IMAGE_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp"
    );

    private final Path uploadRoot;
    public FileStorageService(
            @Value("${app.storage.upload-dir}") String uploadDir
    ) {
        this.uploadRoot = initializeUploadRoot(uploadDir);
    }

    public String storeImage(MultipartFile file, String folder) {
        return storeValidated(file, folder, MAX_IMAGE_BYTES, false);
    }

    public String store(MultipartFile file, String folder) {
        return storeValidated(file, folder, MAX_CHAT_BYTES, true);
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

            Path folderPath = uploadRoot.resolve(folder).normalize();
            if (!folderPath.startsWith(uploadRoot)) {
                throw new IllegalArgumentException("Geçersiz yükleme yolu");
            }
            Files.createDirectories(folderPath);

            String fileName = UUID.randomUUID() + detected.extension();
            Path target = folderPath.resolve(fileName).normalize();
            if (!target.startsWith(folderPath)) {
                throw new IllegalArgumentException("Geçersiz dosya yolu");
            }
            Files.write(target, bytes, StandardOpenOption.CREATE_NEW);
            return "/uploads/" + folder + "/" + fileName;
        } catch (IOException exception) {
            throw new IllegalStateException("Yüklenen dosya kaydedilemedi", exception);
        }
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

    private Path initializeUploadRoot(String configuredDirectory) {
        Path requested = Path.of(configuredDirectory).toAbsolutePath().normalize();
        try {
            Files.createDirectories(requested);
            return requested;
        } catch (IOException | SecurityException primaryFailure) {
            Path fallback = Path.of(
                    System.getProperty("java.io.tmpdir"),
                    "ecovision-uploads"
            ).toAbsolutePath().normalize();
            try {
                Files.createDirectories(fallback);
                LOGGER.warn(
                        "Configured upload directory is unavailable; using temporary storage at {}",
                        fallback
                );
            } catch (IOException | SecurityException fallbackFailure) {
                LOGGER.error(
                        "Temporary upload directory could not be prepared. "
                                + "Uploads will return a controlled error.",
                        fallbackFailure
                );
            }
            return fallback;
        }
    }

    private record DetectedFile(String contentType, String extension) {
    }
}
