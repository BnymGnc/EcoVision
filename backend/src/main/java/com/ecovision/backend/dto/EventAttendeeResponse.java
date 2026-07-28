package com.ecovision.backend.dto;

import com.ecovision.backend.model.EventAttendance;

public record EventAttendeeResponse(
        Long userId,
        String fullName,
        String profilePictureUrl,
        Integer avatarLevel
) {
    public static EventAttendeeResponse from(EventAttendance attendance) {
        return new EventAttendeeResponse(
                attendance.getUser().getId(),
                attendance.getUser().getName() + " " + attendance.getUser().getSurname(),
                attendance.getUser().getProfilePictureUrl(),
                attendance.getUser().getEquippedAvatarLevel()
        );
    }
}
