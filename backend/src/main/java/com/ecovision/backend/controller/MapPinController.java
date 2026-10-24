package com.ecovision.backend.controller;

import com.ecovision.backend.dto.MapPinResponse;
import com.ecovision.backend.service.AdminService;
import com.ecovision.backend.service.DoaMapService;
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
    private final DoaMapService doaMapService;

    public MapPinController(AdminService adminService, DoaMapService doaMapService) {
        this.adminService = adminService;
        this.doaMapService = doaMapService;
    }

    @GetMapping("/nearby")
    public List<DoaMapService.Point> nearby(
            @RequestParam double lat, @RequestParam double lng,
            @RequestParam(required = false) Double radiusKm,
            @RequestParam(required = false) Integer limit,
            @RequestParam(defaultValue = "") Set<String> materials,
            @RequestParam(defaultValue = "DIM") Set<String> pointTypes,
            @RequestParam(defaultValue = "false") boolean openOnly,
            @RequestParam(required = false) Double south, @RequestParam(required = false) Double north,
            @RequestParam(required = false) Double west, @RequestParam(required = false) Double east
    ) {
        return doaMapService.nearby(lat, lng, radiusKm, limit, materials, pointTypes, openOnly, south, north, west, east);
    }

    @GetMapping("/{id}")
    public DoaMapService.Detail detail(@org.springframework.web.bind.annotation.PathVariable Long id) {
        return doaMapService.detail(id);
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
