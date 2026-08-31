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

    long countByType(MapPinType type);
}
