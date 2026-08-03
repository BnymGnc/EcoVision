package com.ecovision.backend.dto;

import com.ecovision.backend.model.EventAttendance;
import com.ecovision.backend.model.AvatarTier;

public record EventAttendeeResponse(
        Long userId,
        String fullName,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
) {
    public static EventAttendeeResponse from(EventAttendance attendance) {
        return new EventAttendeeResponse(
                attendance.getUser().getId(),
                attendance.getUser().getName() + " " + attendance.getUser().getSurname(),
                ProfileImageDtoPolicy.publicCustomPhoto(attendance.getUser()),
                attendance.getUser().getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(
                        attendance.getUser().getLifetimePoints()
                ).level(),
                attendance.getUser().getProfileImagePreference().name(),
                attendance.getUser().getSelectedAvatarPath(),
                attendance.getUser().isAdult(),
                attendance.getUser().getProfileVisibility().name()
        );
    }
}
