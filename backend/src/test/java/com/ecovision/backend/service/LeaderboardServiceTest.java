package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

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
}
