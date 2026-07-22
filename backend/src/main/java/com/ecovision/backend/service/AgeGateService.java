package com.ecovision.backend.service;

import com.ecovision.backend.model.AppUser;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

@Service
public class AgeGateService {
    public void requireAdult(AppUser user) {
        if (!user.isAdult()) {
            throw new AccessDeniedException("Topluluk özellikleri yalnızca 18 yaş ve üzeri kullanıcılar içindir");
        }
    }
}
