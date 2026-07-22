package com.ecovision.backend.repository;

import com.ecovision.backend.model.Event;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventRepository extends JpaRepository<Event, Long> {
    @EntityGraph(attributePaths = "creator")
    List<Event> findAllByOrderByEventDateAsc();
}
