package com.ecovision.backend.dto;

import com.ecovision.backend.model.GroupEventAttendance;

public record GroupEventAttendeeResponse(
        Long userId,
        String fullName,
        String profilePictureUrl
) {
    public static GroupEventAttendeeResponse from(GroupEventAttendance attendance) {
        return new GroupEventAttendeeResponse(
                attendance.getUser().getId(),
                attendance.getUser().getName() + " " + attendance.getUser().getSurname(),
                attendance.getUser().getProfilePictureUrl()
        );
    }
}
