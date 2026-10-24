package com.ecovision.backend.repository;

import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MapPinRepository extends JpaRepository<MapPin, Long> {
    @Override
    @EntityGraph(attributePaths = {
            "createdBy", "acceptedMaterials", "binStates", "binList"
    })
    List<MapPin> findAll();

    @EntityGraph(attributePaths = {
            "createdBy", "acceptedMaterials", "binStates", "binList"
    })
    List<MapPin> findAllByOrderByCreatedAtDesc();

    java.util.Optional<MapPin> findFirstByTitleIgnoreCase(String title);

    java.util.Optional<MapPin> findFirstByProviderAndExternalId(
            String provider,
            String externalId
    );

    long countByProviderAndDatasetHash(String provider, String datasetHash);

    @org.springframework.data.jpa.repository.Query("""
            select p.id as id, p.provider as provider, p.externalId as externalId,
                   p.title as title, p.address as address, p.latitude as latitude,
                   p.longitude as longitude, p.datasetHash as datasetHash, p.snapshotAt as snapshotAt
            from MapPin p
            """)
    List<CatalogIdentity> findCatalogIdentities();

    @org.springframework.data.jpa.repository.Query("""
            select p.id as id, p.title as title, p.latitude as latitude, p.longitude as longitude,
                   p.address as address, p.pointType as pointType,
                   p.sourceMaterialCodesJson as sourceMaterialCodesJson, p.rawBinsJson as rawBinsJson,
                   p.weeklyScheduleJson as weeklyScheduleJson, p.snapshotAt as snapshotAt
            from MapPin p where p.active = true
              and p.latitude between :south and :north and p.longitude between :west and :east
            order by p.id
            """)
    List<PointSummary> findPointSummaries(double south, double north, double west, double east);

    interface PointSummary {
        Long getId(); String getTitle(); Double getLatitude(); Double getLongitude();
        String getAddress(); String getPointType(); String getSourceMaterialCodesJson();
        String getRawBinsJson(); String getWeeklyScheduleJson(); java.time.Instant getSnapshotAt();
    }

    interface CatalogIdentity {
        Long getId();
        String getProvider();
        String getExternalId();
        String getTitle();
        String getAddress();
        Double getLatitude();
        Double getLongitude();
        String getDatasetHash();
        java.time.Instant getSnapshotAt();
    }

    long countByType(MapPinType type);
}
