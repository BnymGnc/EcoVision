package com.ecovision.backend.controller;

import com.ecovision.backend.dto.MapPinResponse;
import com.ecovision.backend.service.AdminService;
import java.util.List;
import java.util.Set;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/map-pins")
public class MapPinController {
    private final AdminService adminService;

    public MapPinController(AdminService adminService) {
        this.adminService = adminService;
    }

    @GetMapping
    public List<MapPinResponse> mapPins() {
        return adminService.getMapPins();
    }

    @GetMapping("/nearest")
    public List<MapPinResponse> nearestMapPins(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(required = false) Double radiusKm,
            @RequestParam(required = false) Integer limit,
            @RequestParam(required = false, defaultValue = "") Set<String> materials
    ) {
        if (radiusKm != null && (radiusKm < 1 || radiusKm > 50)) {
            throw new IllegalArgumentException("Arama yarıçapı 1-50 km olmalıdır");
        }
        return adminService.getNearestMapPins(
                lat,
                lng,
                radiusKm,
                limit,
                materials
        );
    }
}
