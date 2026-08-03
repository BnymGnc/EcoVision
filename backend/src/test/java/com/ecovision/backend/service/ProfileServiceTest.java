package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {
    @Mock private AppUserRepository users;

    @Test
    void minorCannotUploadCustomProfilePicture() {
        AppUser minor = new AppUser();
        minor.setId(7L);
        minor.setAge(17);
        when(users.findByIdForUpdate(7L)).thenReturn(Optional.of(minor));
        ProfileService service = new ProfileService(
                users,
                new FileStorageService(null),
                null,
                null,
                null
        );

        assertThrows(
                IllegalArgumentException.class,
                () -> service.updateProfilePicture(minor, null)
        );
    }
}
