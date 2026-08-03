package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AvatarTier;
import java.util.Set;
import java.time.LocalDate;
import java.time.Instant;

public record UserResponse(
        Long id,
        String username,
        String name,
        String surname,
        String email,
        Integer age,
        String city,
        String district,
        String neighborhood,
        String themePreference,
        String profilePictureUrl,
        String profileImagePreference,
        String selectedAvatarPath,
        Integer equippedAvatarLevel,
        Integer currentAvatarLevel,
        Integer totalPoints,
        Integer lifetimePoints,
        boolean adult,
        Integer streakCount,
        Integer streakFreezeCount,
        LocalDate lastScanDate,
        boolean banned,
        Instant suspendedUntil,
        String role,
        String profileVisibility,
        Set<String> ownedMarketItems
) {
    public static UserResponse from(AppUser user) {
        return new UserResponse(
                user.getId(),
                user.getPublicUsername(),
                user.getName(),
                user.getSurname(),
                user.getEmail(),
                user.getAge(),
                user.getCity(),
                user.getDistrict(),
                user.getNeighborhood(),
                user.getThemePreference(),
                user.getProfilePictureUrl(),
                user.getProfileImagePreference().name(),
                user.getSelectedAvatarPath(),
                user.getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(user.getLifetimePoints()).level(),
                user.getTotalPoints(),
                user.getLifetimePoints(),
                user.isAdult(),
                user.getStreakCount(),
                user.getStreakFreezeCount(),
                user.getLastScanDate(),
                user.isBanned(),
                user.getSuspendedUntil(),
                user.getRole().name(),
                user.getProfileVisibility().name(),
                Set.copyOf(user.getOwnedMarketItems())
        );
    }
}
