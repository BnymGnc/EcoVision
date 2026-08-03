package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ProfileImagePreference;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.GamificationActionRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GamificationServiceAvatarTest {
    @Mock private AppUserRepository users;
    @Mock private GamificationActionRepository actions;

    private GamificationService service;
    private AppUser user;

    @BeforeEach
    void setUp() {
        service = new GamificationService(users, actions, null, null);
        user = new AppUser();
        user.setId(9L);
        user.setName("Avatar");
        user.setSurname("Kullanıcısı");
        user.setEmail("avatar@ecovision.test");
        user.setLifetimePoints(600);
        user.setProfilePictureUrl("/api/media/00000000-0000-0000-0000-000000000001");
        user.setProfileImagePreference(ProfileImagePreference.CUSTOM_PHOTO);
        when(users.findByIdForUpdate(9L)).thenReturn(Optional.of(user));
    }

    @Test
    void unlockedAvatarSelectionPersistsCanonicalAssetPath() {
        when(users.save(any(AppUser.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        UserResponse response = service.equipAvatar(user, 5);

        assertEquals(5, response.equippedAvatarLevel());
        assertEquals(5, response.currentAvatarLevel());
        assertEquals(
                "assets/images/avatars/avatar_level_5.png",
                response.selectedAvatarPath()
        );
        assertEquals(null, response.profilePictureUrl());
        assertEquals("AVATAR", response.profileImagePreference());
    }

    @Test
    void rejectsAvatarAboveCurrentLevel() {
        assertThrows(
                IllegalArgumentException.class,
                () -> service.equipAvatar(user, 6)
        );
    }
}
