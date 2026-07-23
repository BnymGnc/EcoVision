package com.ecovision.backend.repository;

import com.ecovision.backend.model.Quest;
import com.ecovision.backend.model.QuestCategory;
import com.ecovision.backend.model.QuestTriggerType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuestRepository extends JpaRepository<Quest, Long> {
    Optional<Quest> findByCode(String code);

    List<Quest> findByActiveTrueAndQuestCategory(QuestCategory category);

    List<Quest> findByActiveTrueAndTriggerType(QuestTriggerType triggerType);
}
