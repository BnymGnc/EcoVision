package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;

public record UserResponse(
        Long id,
        String name,
        String surname,
        String email,
        Integer age,
        String profilePictureUrl,
        Integer totalPoints,
        String role
) {
    public static UserResponse from(AppUser user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getSurname(),
                user.getEmail(),
                user.getAge(),
                user.getProfilePictureUrl(),
                user.getTotalPoints(),
                user.getRole().name()
        );
    }
}
