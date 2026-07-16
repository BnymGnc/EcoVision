package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
public class CurrentUserService {
    public AppUser currentUser() {
        return (AppUser) SecurityContextHolder.getContext()
                .getAuthentication()
                .getPrincipal();
    }
}
