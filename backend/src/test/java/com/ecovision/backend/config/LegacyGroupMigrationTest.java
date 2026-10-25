package com.ecovision.backend.config;

import com.ecovision.backend.model.*;
import com.ecovision.backend.repository.*;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LegacyGroupMigrationTest {
    @Test void restartDoesNotOverwriteEditedGroupOrReAddKickedMembers() throws Exception {
        var events = mock(EventRepository.class);
        var legacyMembers = mock(EventMemberRepository.class);
        var messages = mock(ChatMessageRepository.class);
        var groups = mock(CommunityGroupRepository.class);
        var members = mock(GroupMemberRepository.class);
        var founder = new AppUser(); founder.setId(1L);
        var legacy = new Event(); legacy.setId(9L); legacy.setTitle("Old event title");
        var group = new CommunityGroup(); org.springframework.test.util.ReflectionTestUtils.setField(group, "id", 7L); group.setCreator(founder);
        group.setName("Edited group name"); group.setCoverImageUrl("/api/media/persistent-image");
        group.setInviteCode("existing-invite");
        when(events.findAllByOrderByEventDateAsc()).thenReturn(List.of(legacy));
        when(groups.findByLegacyEventId(9L)).thenReturn(Optional.of(group));
        when(groups.findAll()).thenReturn(List.of(group));
        when(members.existsByGroupIdAndUserId(7L, 1L)).thenReturn(true);
        var transaction = new org.springframework.transaction.support.AbstractPlatformTransactionManager() {
            protected Object doGetTransaction() { return new Object(); }
            protected void doBegin(Object tx, org.springframework.transaction.TransactionDefinition def) {}
            protected void doCommit(org.springframework.transaction.support.DefaultTransactionStatus status) {}
            protected void doRollback(org.springframework.transaction.support.DefaultTransactionStatus status) {}
        };
        new DataInitializer().migrateLegacyCommunityGroups(events, legacyMembers, messages, groups, members, transaction).run();
        assertEquals("Edited group name", group.getName());
        assertEquals("/api/media/persistent-image", group.getCoverImageUrl());
        verifyNoInteractions(legacyMembers, messages);
        verify(groups, never()).save(any()); verify(members, never()).save(any());
    }
}
