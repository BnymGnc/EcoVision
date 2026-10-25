package com.ecovision.backend.repository;
import com.ecovision.backend.model.CarbonAssessment;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CarbonAssessmentRepository extends JpaRepository<CarbonAssessment, Long> {
    List<CarbonAssessment> findTop12ByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<CarbonAssessment> findTopByUserIdOrderByCreatedAtDescIdDesc(Long userId);
}
