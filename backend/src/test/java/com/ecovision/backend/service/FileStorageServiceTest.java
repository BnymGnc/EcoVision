package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.MediaAsset;
import com.ecovision.backend.repository.MediaAssetRepository;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
class FileStorageServiceTest {
    @Mock private MediaAssetRepository mediaAssets;

    @Test
    void storesValidatedImageInDatabase() {
        AtomicReference<MediaAsset> saved = new AtomicReference<>();
        when(mediaAssets.save(any(MediaAsset.class))).thenAnswer(invocation -> {
            MediaAsset asset = invocation.getArgument(0);
            saved.set(asset);
            return asset;
        });
        byte[] png = new byte[] {
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        };
        MockMultipartFile upload = new MockMultipartFile(
                "image",
                "avatar.png",
                "image/png",
                png
        );

        String url = new FileStorageService(mediaAssets)
                .storeImage(upload, "profiles");

        assertTrue(url.startsWith("/api/media/"));
        assertEquals("image/png", saved.get().getContentType());
        assertEquals("profiles", saved.get().getCategory());
        assertArrayEquals(png, saved.get().getData());
    }
}
