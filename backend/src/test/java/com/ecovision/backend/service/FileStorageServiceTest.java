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
    void storesValidatedImageInDatabase() throws Exception {
        AtomicReference<MediaAsset> saved = new AtomicReference<>();
        when(mediaAssets.save(any(MediaAsset.class))).thenAnswer(invocation -> {
            MediaAsset asset = invocation.getArgument(0);
            saved.set(asset);
            return asset;
        });
        var output = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2, 2, 1), "png", output);
        byte[] png = output.toByteArray();
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

    @Test void rejectsTruncatedImageBeforeDatabaseWrite() {
        var file=new MockMultipartFile("image","fake.png","image/png",
            new byte[]{(byte)0x89,0x50,0x4e,0x47,13,10,26,10});
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
            ()->new FileStorageService(mediaAssets).storeImage(file,"profiles"));
        org.mockito.Mockito.verifyNoInteractions(mediaAssets);
    }
    @Test void rejectsPixelBombBeforeDecodingPixels() throws Exception {
        var out=new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2,2,1),"png",out);
        byte[] bytes=out.toByteArray();
        java.nio.ByteBuffer.wrap(bytes,16,8).putInt(25000).putInt(25000);
        var file=new MockMultipartFile("image","huge.png","image/png",bytes);
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
            ()->new FileStorageService(mediaAssets).storeImage(file,"profiles"));
        org.mockito.Mockito.verifyNoInteractions(mediaAssets);
    }
}
