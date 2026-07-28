package com.ecovision.backend.controller;

import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.ProfileService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/users")
public class UserProfilePictureController {
    private final ProfileService profileService;
    private final CurrentUserService currentUserService;

    public UserProfilePictureController(
            ProfileService profileService,
            CurrentUserService currentUserService
    ) {
        this.profileService = profileService;
        this.currentUserService = currentUserService;
    }

    @PostMapping(
            value = "/profile-picture",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public UserResponse upload(@RequestParam("image") MultipartFile image) {
        return profileService.updateProfilePicture(
                currentUserService.currentUser(),
                image
        );
    }
}
