package com.ecovision.backend.repository;

import com.ecovision.backend.model.ScanHistory;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScanHistoryRepository extends JpaRepository<ScanHistory, Long> {
    List<ScanHistory> findByUserIdOrderByScannedAtDesc(Long userId);

    long countByUserIdAndScannedAtAfter(Long userId, Instant scannedAt);

    Optional<ScanHistory> findFirstByUserIdAndScannedAtAfterOrderByScannedAtAsc(
            Long userId,
            Instant scannedAt
    );

    long countByUserIdAndMaterialTypeIgnoreCase(Long userId, String materialType);
}
