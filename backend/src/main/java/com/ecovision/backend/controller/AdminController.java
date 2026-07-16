package com.ecovision.backend.controller;

import com.ecovision.backend.dto.AssignAdminRequest;
import com.ecovision.backend.dto.MapPinRequest;
import com.ecovision.backend.dto.MapPinResponse;
import com.ecovision.backend.dto.UserResponse;
import com.ecovision.backend.service.AdminService;
import com.ecovision.backend.service.CurrentUserService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminController {
    private final AdminService adminService;
    private final CurrentUserService currentUserService;

    public AdminController(AdminService adminService, CurrentUserService currentUserService) {
        this.adminService = adminService;
        this.currentUserService = currentUserService;
    }

    @GetMapping("/users")
    public List<UserResponse> users() {
        return adminService.getUsers();
    }

    @PostMapping("/assign-admin")
    public UserResponse assignAdmin(@Valid @RequestBody AssignAdminRequest request) {
        return adminService.assignAdmin(request);
    }

    @PostMapping("/map-pins")
    public MapPinResponse addOfficialMapPin(@Valid @RequestBody MapPinRequest request) {
        return adminService.addOfficialMapPin(currentUserService.currentUser(), request);
    }
}
