package com.ecovision.backend.dto;

public record AuthResponse(String token, UserResponse user) {
}
