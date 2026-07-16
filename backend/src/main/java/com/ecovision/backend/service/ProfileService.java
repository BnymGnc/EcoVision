package com.ecovision.backend.service;

import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileService {
    private final AppUserRepository userRepository;
    private final FileStorageService fileStorageService;

    public ProfileService(AppUserRepository userRepository, FileStorageService fileStorageService) {
        this.userRepository = userRepository;
        this.fileStorageService = fileStorageService;
    }

    @Transactional
    public UserResponse updateProfilePicture(AppUser user, MultipartFile image) {
        String url = fileStorageService.store(image, "profiles");
        user.setProfilePictureUrl(url);
        return UserResponse.from(userRepository.save(user));
    }
}
