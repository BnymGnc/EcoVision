package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChangePasswordRequest;
import com.ecovision.backend.dto.UpdateProfileRequest;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.repository.AppUserRepository;
import org.springframework.stereotype.Service;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileService {
    private final AppUserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final PasswordEncoder passwordEncoder;

    public ProfileService(
            AppUserRepository userRepository,
            FileStorageService fileStorageService,
            PasswordEncoder passwordEncoder
    ) {
        this.userRepository = userRepository;
        this.fileStorageService = fileStorageService;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public UserResponse updateProfilePicture(AppUser user, MultipartFile image) {
        String url = fileStorageService.store(image, "profiles");
        user.setProfilePictureUrl(url);
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateProfile(AppUser currentUser, UpdateProfileRequest request) {
        AppUser user = lockUser(currentUser.getId());
        user.setName(request.name().trim());
        user.setSurname(request.surname().trim());
        user.setAge(request.age());
        user.setCity(request.city().trim());
        user.setDistrict(request.district().trim());
        user.setNeighborhood(request.neighborhood().trim());
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public void changePassword(AppUser currentUser, ChangePasswordRequest request) {
        AppUser user = lockUser(currentUser.getId());
        if (!passwordEncoder.matches(request.currentPassword(), user.getPassword())) {
            throw new IllegalArgumentException("Mevcut parola hatalı");
        }
        if (passwordEncoder.matches(request.newPassword(), user.getPassword())) {
            throw new IllegalArgumentException("Yeni parola mevcut paroladan farklı olmalı");
        }
        user.setPassword(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
    }

    private AppUser lockUser(Long userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
    }
}
