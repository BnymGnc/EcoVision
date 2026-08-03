package com.ecovision.backend.dto;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.ProfileImagePreference;
import com.ecovision.backend.model.ProfileVisibility;

final class ProfileImageDtoPolicy {
    private ProfileImageDtoPolicy() {
    }

    static String publicCustomPhoto(AppUser user) {
        if (!user.isAdult()
                || user.getProfileImagePreference()
                != ProfileImagePreference.CUSTOM_PHOTO
                || user.getProfileVisibility() != ProfileVisibility.PUBLIC) {
            return null;
        }
        return user.getProfilePictureUrl();
    }
}
