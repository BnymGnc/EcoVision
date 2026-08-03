package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupEventAttendance;
import com.ecovision.backend.model.AvatarTier;

public record GroupEventAttendeeResponse(
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
    public static GroupEventAttendeeResponse from(GroupEventAttendance attendance) {
        return new GroupEventAttendeeResponse(
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
