package com.ecovision.backend.service;

import com.ecovision.backend.dto.ChangePasswordRequest;
import com.ecovision.backend.dto.UpdateProfileRequest;
import com.ecovision.backend.dto.ProfileVisibilityRequest;
import com.ecovision.backend.dto.ThemePreferenceRequest;
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
    private final UsernameService usernameService;
    private final InputSanitizer inputSanitizer;

    public ProfileService(
            AppUserRepository userRepository,
            FileStorageService fileStorageService,
            PasswordEncoder passwordEncoder,
            UsernameService usernameService,
            InputSanitizer inputSanitizer
    ) {
        this.userRepository = userRepository;
        this.fileStorageService = fileStorageService;
        this.passwordEncoder = passwordEncoder;
        this.usernameService = usernameService;
        this.inputSanitizer = inputSanitizer;
    }

    @Transactional
    public UserResponse updateProfilePicture(AppUser user, MultipartFile image) {
        String url = fileStorageService.replaceImage(
                image,
                "profiles",
                user.getProfilePictureUrl()
        );
        user.setProfilePictureUrl(url);
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateProfile(AppUser currentUser, UpdateProfileRequest request) {
        AppUser user = lockUser(currentUser.getId());
        user.setName(inputSanitizer.plainText(request.name(), "Ad", 60));
        user.setSurname(inputSanitizer.plainText(request.surname(), "Soyad", 60));
        user.setAge(request.age());
        user.setCity(inputSanitizer.plainText(request.city(), "İl", 60));
        user.setDistrict(inputSanitizer.plainText(request.district(), "İlçe", 60));
        user.setNeighborhood(inputSanitizer.plainText(
                request.neighborhood(),
                "Mahalle",
                100
        ));
        if (request.username() != null && !request.username().isBlank()) {
            user.setPublicUsername(
                    usernameService.validateForUpdate(user.getId(), request.username())
            );
        }
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateVisibility(
            AppUser currentUser,
            ProfileVisibilityRequest request
    ) {
        AppUser user = lockUser(currentUser.getId());
        user.setProfileVisibility(request.visibility());
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateTheme(
            AppUser currentUser,
            ThemePreferenceRequest request
    ) {
        AppUser user = lockUser(currentUser.getId());
        user.setThemePreference(request.themePreference());
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
