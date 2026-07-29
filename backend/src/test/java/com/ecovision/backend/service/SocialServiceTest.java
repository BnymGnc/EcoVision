package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ProfileVisibility;
import com.ecovision.backend.repository.AppNotificationRepository;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.FriendshipRepository;
import com.ecovision.backend.repository.GroupInviteRepository;
import com.ecovision.backend.repository.ProfileLikeRepository;
import com.ecovision.backend.repository.ScanHistoryRepository;
import com.ecovision.backend.repository.SocialReportRepository;
import com.ecovision.backend.repository.UserBadgeRepository;
import com.ecovision.backend.repository.UserBlockRepository;
import java.util.Optional;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SocialServiceTest {
    @Mock private AppUserRepository users;
    @Mock private FriendshipRepository friendships;
    @Mock private ProfileLikeRepository likes;
    @Mock private UserBlockRepository blocks;
    @Mock private GroupInviteRepository invites;
    @Mock private SocialReportRepository reports;
    @Mock private EventRepository events;
    @Mock private EventMemberRepository members;
    @Mock private UserBadgeRepository userBadges;
    @Mock private ScanHistoryRepository scans;
    @Mock private AppNotificationRepository appNotifications;
    @Mock private ChatMessageRepository chatMessages;

    private SocialService service;

    @BeforeEach
    void setUp() {
        GroupActivityMessageService groupActivity =
                new GroupActivityMessageService(members, chatMessages);
        NotificationService notifications = new NotificationService(appNotifications, users);
        BadgeService badges = new BadgeService(
                userBadges,
                scans,
                likes,
                notifications,
                groupActivity
        );
        service = new SocialService(
                users,
                friendships,
                likes,
                blocks,
                invites,
                reports,
                events,
                members,
                new AgeGateService(),
                badges,
                notifications
        );
    }

    @Test
    void friendsOnlyProfileRedactsPrivateDetailsForNonFriend() {
        AppUser current = adult(1L, "ada", ProfileVisibility.PUBLIC);
        AppUser target = adult(2L, "deniz", ProfileVisibility.FRIENDS_ONLY);
        when(users.findById(2L)).thenReturn(Optional.of(target));
        when(friendships.findBetween(1L, 2L)).thenReturn(Optional.empty());

        assertFalse(service.profile(current, 2L).detailsVisible());
    }

    @Test
    void partialSearchReturnsAdultMatches() {
        AppUser current = adult(1L, "ada", ProfileVisibility.PUBLIC);
        AppUser target = adult(2L, "deniz", ProfileVisibility.PUBLIC);
        when(users.searchAdultUsers(eq("den"), any(), any()))
                .thenReturn(List.of(target));
        when(friendships.findBetween(1L, 2L)).thenReturn(Optional.empty());

        var results = service.searchUsers(current, " Den ");

        assertEquals(1, results.size());
        assertEquals("deniz", results.get(0).username());
    }

    @Test
    void partialSearchRequiresThreeCharacters() {
        AppUser current = adult(1L, "ada", ProfileVisibility.PUBLIC);

        assertThrows(
                IllegalArgumentException.class,
                () -> service.searchUsers(current, "de")
        );
    }

    private AppUser adult(Long id, String username, ProfileVisibility visibility) {
        AppUser user = new AppUser();
        user.setId(id);
        user.setAge(25);
        user.setName(username);
        user.setSurname("Eco");
        user.setPublicUsername(username);
        user.setProfileVisibility(visibility);
        return user;
    }
}
