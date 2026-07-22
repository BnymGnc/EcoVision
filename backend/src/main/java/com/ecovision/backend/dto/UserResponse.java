package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import java.util.Set;
import java.time.LocalDate;
import java.time.Instant;

public record UserResponse(
        Long id,
        String name,
        String surname,
        String email,
        Integer age,
        String city,
        String district,
        String neighborhood,
        String profilePictureUrl,
        Integer equippedAvatarLevel,
        Integer totalPoints,
        Integer lifetimePoints,
        boolean adult,
        Integer streakCount,
        Integer streakFreezeCount,
        LocalDate lastScanDate,
        boolean banned,
        Instant suspendedUntil,
        String role,
        Set<String> ownedMarketItems
) {
    public static UserResponse from(AppUser user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getSurname(),
                user.getEmail(),
                user.getAge(),
                user.getCity(),
                user.getDistrict(),
                user.getNeighborhood(),
                user.getProfilePictureUrl(),
                user.getEquippedAvatarLevel(),
                user.getTotalPoints(),
                user.getLifetimePoints(),
                user.isAdult(),
                user.getStreakCount(),
                user.getStreakFreezeCount(),
                user.getLastScanDate(),
                user.isBanned(),
                user.getSuspendedUntil(),
                user.getRole().name(),
                Set.copyOf(user.getOwnedMarketItems())
        );
    }
}
