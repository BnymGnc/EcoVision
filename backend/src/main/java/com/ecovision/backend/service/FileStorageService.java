package com.ecovision.backend.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

@Service
public class FileStorageService {
    private final Path uploadRoot;
    private final String publicBaseUrl;

    public FileStorageService(
            @Value("${app.storage.upload-dir}") String uploadDir,
            @Value("${app.storage.public-base-url}") String publicBaseUrl
    ) throws IOException {
        this.uploadRoot = Path.of(uploadDir).toAbsolutePath().normalize();
        this.publicBaseUrl = publicBaseUrl;
        Files.createDirectories(uploadRoot);
    }

    public String store(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) {
            return null;
        }

        try {
            Path folderPath = uploadRoot.resolve(folder).normalize();
            Files.createDirectories(folderPath);

            String originalName = StringUtils.cleanPath(file.getOriginalFilename() == null
                    ? "upload"
                    : file.getOriginalFilename());
            String extension = "";
            int dot = originalName.lastIndexOf('.');
            if (dot >= 0) {
                extension = originalName.substring(dot);
            }

            String fileName = UUID.randomUUID() + extension;
            Path target = folderPath.resolve(fileName).normalize();
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);

            return publicBaseUrl + "/uploads/" + folder + "/" + fileName;
        } catch (IOException exception) {
            throw new IllegalStateException("Could not store upload", exception);
        }
    }
}
