package com.ecovision.backend.repository;

import com.ecovision.backend.model.ScanHistory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScanHistoryRepository extends JpaRepository<ScanHistory, Long> {
    List<ScanHistory> findByUserIdOrderByScannedAtDesc(Long userId);
}
