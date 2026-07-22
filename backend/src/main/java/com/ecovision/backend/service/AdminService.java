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
    private final OverpassMapPinService overpassMapPinService;

    public AdminService(
            AppUserRepository userRepository,
            MapPinRepository mapPinRepository,
            OverpassMapPinService overpassMapPinService
    ) {
        this.userRepository = userRepository;
        this.mapPinRepository = mapPinRepository;
        this.overpassMapPinService = overpassMapPinService;
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

    @Transactional(readOnly = true)
    public List<MapPinResponse> getMapPins() {
        return mapPinRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(MapPinResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<MapPinResponse> getNearestMapPins(
            double latitude,
            double longitude,
            Double radiusKm,
            Integer limit
    ) {
        List<MapPinResponse> localPins = mapPinRepository.findAll()
                .stream()
                .map(pin -> new PinDistance(pin, haversineKm(
                        latitude,
                        longitude,
                        pin.getLatitude(),
                        pin.getLongitude()
                )))
                .filter(item -> radiusKm == null || item.distanceKm() <= radiusKm)
                .sorted((left, right) -> Double.compare(left.distanceKm(), right.distanceKm()))
                .limit(limit == null || limit <= 0 ? Long.MAX_VALUE : limit)
                .map(item -> MapPinResponse.from(item.pin(), item.distanceKm()))
                .toList();

        if (!localPins.isEmpty()) {
            return localPins;
        }

        return overpassMapPinService.findNearest(latitude, longitude, radiusKm, limit);
    }

    private double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2)
                * Math.sin(dLon / 2);
        return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private record PinDistance(MapPin pin, double distanceKm) {
    }
}
