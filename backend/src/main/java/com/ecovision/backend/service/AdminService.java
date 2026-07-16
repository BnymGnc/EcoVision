package com.ecovision.backend.service;

import com.ecovision.backend.dto.AssignAdminRequest;
import com.ecovision.backend.dto.MapPinRequest;
import com.ecovision.backend.dto.MapPinResponse;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.MapPinRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {
    private final AppUserRepository userRepository;
    private final MapPinRepository mapPinRepository;

    public AdminService(AppUserRepository userRepository, MapPinRepository mapPinRepository) {
        this.userRepository = userRepository;
        this.mapPinRepository = mapPinRepository;
    }

    public List<UserResponse> getUsers() {
        return userRepository.findAll()
                .stream()
                .map(UserResponse::from)
                .toList();
    }

    @Transactional
    public UserResponse assignAdmin(AssignAdminRequest request) {
        AppUser user = userRepository.findByEmail(request.email().trim().toLowerCase())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setRole(Role.ADMIN);
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public MapPinResponse addOfficialMapPin(AppUser creator, MapPinRequest request) {
        MapPin pin = new MapPin();
        pin.setTitle(request.title());
        pin.setLatitude(request.latitude());
        pin.setLongitude(request.longitude());
        pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
        pin.setCreatedBy(creator);
        return MapPinResponse.from(mapPinRepository.save(pin));
    }

    public List<MapPinResponse> getMapPins() {
        return mapPinRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(MapPinResponse::from)
                .toList();
    }
}
