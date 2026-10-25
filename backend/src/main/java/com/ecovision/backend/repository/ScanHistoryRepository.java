package com.ecovision.backend.repository;

import com.ecovision.backend.model.ScanHistory;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScanHistoryRepository extends JpaRepository<ScanHistory, Long> {
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
