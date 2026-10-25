package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.assertThrows;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import com.ecovision.backend.dto.CityLeaderboardEntry;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Friendship;
import com.ecovision.backend.model.FriendshipStatus;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.FriendshipRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class LeaderboardServiceTest {
    @Mock
    private AppUserRepository userRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    private LeaderboardService service;

    @BeforeEach
    void setUp() {
        service = new LeaderboardService(userRepository, friendshipRepository);
    }

    @Test
    void friendsLeaderboardContainsOnlyAcceptedFriendsAndCurrentUser() {
        AppUser current = user(1L, "ada", 120);
        AppUser friend = user(2L, "deniz", 240);
        Friendship accepted = new Friendship();
        accepted.setRequester(current);
        accepted.setAddressee(friend);
        accepted.setStatus(FriendshipStatus.ACCEPTED);
        when(friendshipRepository.findForUser(1L, FriendshipStatus.ACCEPTED))
                .thenReturn(List.of(accepted));

        List<CityLeaderboardEntry> result = service.friendsLeaderboard(current);

        assertEquals(List.of("deniz", "ada"), result.stream()
                .map(CityLeaderboardEntry::username)
                .toList());
        assertEquals(List.of(1, 2), result.stream()
                .map(CityLeaderboardEntry::rank)
                .toList());
        assertTrue(result.get(1).currentUser());
    }

    private AppUser user(Long id, String username, int points) {
        AppUser user = new AppUser();
        user.setId(id);
        user.setPublicUsername(username);
        user.setName(username);
        user.setSurname("Eco");
        user.setCity(AppUser.DEFAULT_CITY);
        user.setTotalPoints(points);
        return user;
    }

    @Test
    void globalLeaderboardDoesNotDefaultToCurrentUsersCityAndPreservesPageRanks() {
        var current = user(1L, "ada", 120);
        var another = user(2L, "deniz", 240);
        another.setCity("İzmir");
        when(userRepository.findRankedUsers(eq(""), eq(PageRequest.of(1, 1))))
                .thenReturn(new PageImpl<>(List.of(another), PageRequest.of(1, 1), 3));
        when(friendshipRepository.findForUser(1L, FriendshipStatus.ACCEPTED)).thenReturn(List.of());
        var result = service.globalLeaderboard(current, null, 1, 1);
        assertEquals(2, result.items().get(0).rank());
        assertEquals("İzmir", result.items().get(0).city());
        assertTrue(result.hasMore());
        assertEquals(3, result.total());
    }

    @Test
    void explicitCityFilterIsTrimmedAndDoesNotLoadAllUsers() {
        var current = user(1L, "ada", 120);
        when(userRepository.findRankedUsers("Adana", PageRequest.of(0, 50)))
                .thenReturn(new PageImpl<>(List.of(current)));
        when(friendshipRepository.findForUser(1L, FriendshipStatus.ACCEPTED)).thenReturn(List.of());
        service.globalLeaderboard(current, " Adana ", 0, 50);
        verify(userRepository).findRankedUsers("Adana", PageRequest.of(0, 50));
    }

    @Test
    void invalidPaginationIsRejected() {
        assertThrows(IllegalArgumentException.class, () -> service.globalLeaderboard(user(1L, "a", 0), null, -1, 50));
        assertThrows(IllegalArgumentException.class, () -> service.globalLeaderboard(user(1L, "a", 0), null, 0, 1000));
    }
}
