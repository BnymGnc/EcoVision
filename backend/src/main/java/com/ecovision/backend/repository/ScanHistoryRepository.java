package com.ecovision.backend.repository;

import com.ecovision.backend.model.ScanHistory;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScanHistoryRepository extends JpaRepository<ScanHistory, Long> {
    interface RecyclingCount {
        String getMaterial();
        long getScanCount();
    }

    // Aggregate in PostgreSQL; never load a user's entire history for the dashboard.
    @org.springframework.data.jpa.repository.Query("""
        select coalesce(s.impactMaterial, s.materialType) as material, count(s) as scanCount
        from ScanHistory s
        where s.user.id = :userId and s.isRecyclable = true and s.pointsAwarded > 0
          and (s.imageHash is null or s.imageHash = '' or not exists (
            select earlier.id from ScanHistory earlier
            where earlier.user.id = s.user.id and earlier.imageHash = s.imageHash
              and earlier.pointsAwarded > 0 and earlier.id < s.id))
        group by coalesce(s.impactMaterial, s.materialType)
        """)
    List<RecyclingCount> recyclingCounts(
        @org.springframework.data.repository.query.Param("userId") Long userId);

    boolean existsByUserIdAndImageHashAndPointsAwardedGreaterThan(
        Long userId, String imageHash, int points);
    List<ScanHistory> findByUserIdOrderByScannedAtDesc(Long userId);

    long countByUserIdAndScannedAtAfter(Long userId, Instant scannedAt);

    Optional<ScanHistory> findFirstByUserIdAndScannedAtAfterOrderByScannedAtAsc(
            Long userId,
            Instant scannedAt
    );

    @org.springframework.data.jpa.repository.Query("""
        select count(s) from ScanHistory s where s.user.id=:userId
        and lower(s.materialType)=lower(:materialType) and s.pointsAwarded>0
        """)
    long countByUserIdAndMaterialTypeIgnoreCase(
        @org.springframework.data.repository.query.Param("userId") Long userId,
        @org.springframework.data.repository.query.Param("materialType") String materialType);
}
