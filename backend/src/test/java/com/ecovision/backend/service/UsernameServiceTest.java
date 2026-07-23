package com.ecovision.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UsernameServiceTest {
    @Mock
    private AppUserRepository userRepository;

    private UsernameService service;

    @BeforeEach
    void setUp() {
        service = new UsernameService(userRepository);
    }

    @Test
    void createsStableUniqueUsernameFromEmail() {
        when(userRepository.existsByPublicUsername("ada")).thenReturn(true);
        when(userRepository.existsByPublicUsername("ada_2")).thenReturn(false);

        assertEquals("ada_2", service.createUnique(null, "Ada@example.com"));
    }

    @Test
    void rejectsUsernameOwnedByAnotherUser() {
        AppUser owner = new AppUser();
        owner.setId(9L);
        when(userRepository.findByPublicUsername("deniz")).thenReturn(Optional.of(owner));

        assertThrows(
                IllegalArgumentException.class,
                () -> service.validateForUpdate(3L, "deniz")
        );
    }
}
