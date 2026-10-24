package com.ecovision.backend.repository;
import com.ecovision.backend.model.WasteAction;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
public interface WasteActionRepository extends JpaRepository<WasteAction, Long> {
    Optional<WasteAction> findByUserIdAndActionKey(Long userId, String key);
    List<WasteAction> findTop100ByUserIdOrderByCreatedAtDesc(Long userId);
    @Query("select sum(a.estimatedDifferenceKg) from WasteAction a where a.user.id = :userId")
    Double totalForUser(Long userId);
    long countByUserId(Long userId);
}
