package com.ecovision.backend.service;

import com.ecovision.backend.dto.ScanAnalysisRequest;
import com.ecovision.backend.dto.ScanAnalysisResponse;
import com.ecovision.backend.dto.ScanRequest;
import com.ecovision.backend.dto.ScanResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ScanHistory;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import java.util.List;
import java.util.Locale;
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

        return ScanResponse.from(saveScanAndAwardPoints(user, scan));
    }

    @Transactional
    public ScanAnalysisResponse analyzeAndSave(AppUser user, ScanAnalysisRequest request) {
        MaterialFacts facts = materialFacts(request.detectedClass());

        ScanHistory scan = new ScanHistory();
        scan.setUser(user);
        scan.setMaterialType(facts.materialType());
        scan.setIsRecyclable(facts.recyclable());
        scan.setDecayYears(facts.decayYears());
        scan.setRecycledInto(facts.recycledInto());

        return ScanAnalysisResponse.from(saveScanAndAwardPoints(user, scan));
    }

    private ScanHistory saveScanAndAwardPoints(AppUser user, ScanHistory scan) {
        user.setTotalPoints(user.getTotalPoints() + POINTS_PER_SCAN);
        userRepository.save(user);
        return scanHistoryRepository.save(scan);
    }

    private MaterialFacts materialFacts(String detectedClass) {
        String material = detectedClass == null ? "Unknown waste" : detectedClass.trim();
        if (material.isBlank()) {
            material = "Unknown waste";
        }

        String normalized = material.toLowerCase(Locale.ROOT);
        if (normalized.contains("plastic")) {
            return new MaterialFacts(material, true, "450 years", "new bottles, fibers, containers");
        }
        if (normalized.contains("glass")) {
            return new MaterialFacts(material, true, "1 million years", "new jars, bottles, fiberglass");
        }
        if (normalized.contains("paper") || normalized.contains("cardboard")) {
            return new MaterialFacts(material, true, "2-6 weeks", "paper towels, cartons, packaging");
        }
        if (normalized.contains("metal") || normalized.contains("aluminum") || normalized.contains("can")) {
            return new MaterialFacts(material, true, "80-200 years", "new cans, foil, construction materials");
        }
        if (normalized.contains("organic") || normalized.contains("food")) {
            return new MaterialFacts(material, false, "2-8 weeks", "compost or biogas");
        }
        return new MaterialFacts(material, false, "Unknown", "specialized waste processing");
    }

    private record MaterialFacts(
            String materialType,
            Boolean recyclable,
            String decayYears,
            String recycledInto
    ) {
    }
}
