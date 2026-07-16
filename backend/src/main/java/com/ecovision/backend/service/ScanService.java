package com.ecovision.backend.service;

import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ScanHistory;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScanService {
    private static final int POINTS_PER_SCAN = 10;

    private final ScanHistoryRepository scanHistoryRepository;
    private final AppUserRepository userRepository;

    public ScanService(
            ScanHistoryRepository scanHistoryRepository,
            AppUserRepository userRepository
    ) {
        this.scanHistoryRepository = scanHistoryRepository;
        this.userRepository = userRepository;
    }

    public List<ScanResponse> getScans(AppUser user) {
        return scanHistoryRepository.findByUserIdOrderByScannedAtDesc(user.getId())
                .stream()
                .map(ScanResponse::from)
                .toList();
    }

    @Transactional
    public ScanResponse saveScan(AppUser user, ScanRequest request) {
        ScanHistory scan = new ScanHistory();
        scan.setUser(user);
        scan.setMaterialType(request.materialType());
        scan.setIsRecyclable(request.recyclable());

        user.setTotalPoints(user.getTotalPoints() + POINTS_PER_SCAN);
        userRepository.save(user);

        return ScanResponse.from(scanHistoryRepository.save(scan));
    }
}
