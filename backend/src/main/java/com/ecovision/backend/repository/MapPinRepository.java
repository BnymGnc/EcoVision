package com.ecovision.backend.repository;

import com.ecovision.backend.model.MapPin;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MapPinRepository extends JpaRepository<MapPin, Long> {
    @Override
    @EntityGraph(attributePaths = "createdBy")
    List<MapPin> findAll();

    @EntityGraph(attributePaths = "createdBy")
    List<MapPin> findAllByOrderByCreatedAtDesc();
}
