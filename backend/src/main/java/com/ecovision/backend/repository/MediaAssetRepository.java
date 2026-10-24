package com.ecovision.backend.repository;

import com.ecovision.backend.model.MediaAsset;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MediaAssetRepository extends JpaRepository<MediaAsset, UUID> {
    @org.springframework.data.jpa.repository.Query("select m.category as category, m.ownerUserId as ownerUserId from MediaAsset m where m.id=:id")
    java.util.Optional<Descriptor> describe(@org.springframework.data.repository.query.Param("id") UUID id);
    interface Descriptor {
        String getCategory();
        Long getOwnerUserId();
    }
}
