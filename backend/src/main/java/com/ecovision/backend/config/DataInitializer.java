package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataInitializer {
    @Bean
    CommandLineRunner seedSuperuser(
            AppUserRepository userRepository,
            PasswordEncoder passwordEncoder
    ) {
        return args -> {
            String email = "admin@ecovision.com";
            if (userRepository.existsByEmail(email)) {
                return;
            }

            AppUser superuser = new AppUser();
            superuser.setName("EcoVision");
            superuser.setSurname("Superuser");
            superuser.setEmail(email);
            superuser.setPassword(passwordEncoder.encode("EcoVisionAdmin2026!"));
            superuser.setAge(1);
            superuser.setTotalPoints(0);
            superuser.setRole(Role.SUPERUSER);
            userRepository.save(superuser);
        };
    }
}
