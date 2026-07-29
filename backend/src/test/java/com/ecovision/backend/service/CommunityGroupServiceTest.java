package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.GroupEventAttendanceRepository;
import com.ecovision.backend.repository.GroupEventRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.repository.GroupJoinRequestRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class CommunityGroupServiceTest {
    @Mock private CommunityGroupRepository groups;
    @Mock private AppUserRepository users;
    @Mock private GroupMemberRepository members;
    @Mock private GroupEventRepository events;
    @Mock private GroupEventAttendanceRepository attendance;
    @Mock private ChatMessageRepository chatMessages;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private GroupJoinRequestRepository joinRequests;

    private CommunityGroupService service;
    private CommunityGroup group;
    private AppUser founder;

    @BeforeEach
    void setUp() {
        service = new CommunityGroupService(
                groups,
                users,
                members,
                events,
                attendance,
                chatMessages,
                new AgeGateService(),
                new InputSanitizer(),
                null,
                passwordEncoder,
                null,
                joinRequests
        );
        founder = user(1L, "kurucu");
        group = new CommunityGroup();
        group.setCreator(founder);
        when(groups.findById(10L)).thenReturn(Optional.of(group));
    }

    @Test
    void adminCannotKickAnotherAdmin() {
        AppUser actorUser = user(2L, "yonetici");
        GroupMember actor = member(actorUser, GroupRole.ADMIN);
        GroupMember target = member(user(3L, "diger"), GroupRole.ADMIN);
        when(members.findByGroupIdAndUserId(10L, 2L))
                .thenReturn(Optional.of(actor));

        assertThrows(
                AccessDeniedException.class,
                () -> service.removeMember(actorUser, 10L, 3L)
        );
        verify(members, never()).delete(target);
    }

    @Test
    void founderCanPromoteMember() {
        when(chatMessages.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        GroupMember owner = member(founder, GroupRole.FOUNDER);
        GroupMember target = member(user(3L, "uye"), GroupRole.MEMBER);
        when(members.findByGroupIdAndUserId(10L, 1L))
                .thenReturn(Optional.of(owner));
        when(members.findByGroupIdAndUserId(10L, 3L))
                .thenReturn(Optional.of(target));
        when(members.save(target)).thenReturn(target);

        service.promote(founder, 10L, 3L);

        assertEquals(GroupRole.ADMIN, target.getRole());
    }

    @Test
    void adminCannotPromoteMember() {
        AppUser adminUser = user(2L, "yonetici");
        GroupMember admin = member(adminUser, GroupRole.ADMIN);
        GroupMember target = member(user(3L, "uye"), GroupRole.MEMBER);
        when(members.findByGroupIdAndUserId(10L, 2L))
                .thenReturn(Optional.of(admin));

        assertThrows(
                AccessDeniedException.class,
                () -> service.promote(adminUser, 10L, target.getUser().getId())
        );
    }

    @Test
    void passwordProtectedGroupRejectsWrongPasswordWithoutApprovalFlow() {
        AppUser joiningUser = user(4L, "katilimci");
        group.setPrivateGroup(true);
        group.setJoinCodeHash("bcrypt-hash");
        when(members.existsByGroupIdAndUserId(10L, 4L)).thenReturn(false);
        when(members.countByGroupId(10L)).thenReturn(1L);
        when(passwordEncoder.matches("yanlis", "bcrypt-hash"))
                .thenReturn(false);

        IllegalArgumentException exception = assertThrows(
                IllegalArgumentException.class,
                () -> service.join(
                        joiningUser,
                        10L,
                        new JoinEventRequest("yanlis")
                )
        );

        assertEquals("Grup şifresi hatalı", exception.getMessage());
        verify(members, never()).saveAndFlush(any(GroupMember.class));
    }

    private GroupMember member(AppUser user, GroupRole role) {
        GroupMember member = new GroupMember();
        member.setGroup(group);
        member.setUser(user);
        member.setRole(role);
        return member;
    }

    private AppUser user(Long id, String username) {
        AppUser user = new AppUser();
        user.setId(id);
        user.setAge(25);
        user.setName(username);
        user.setSurname("Eco");
        user.setPublicUsername(username);
        return user;
    }
}
