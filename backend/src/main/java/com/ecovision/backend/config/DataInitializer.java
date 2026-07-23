package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.service.UsernameService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataInitializer {
    @Bean
    CommandLineRunner seedSuperuser(
            AppUserRepository userRepository,
            EventRepository eventRepository,
            PasswordEncoder passwordEncoder,
            UsernameService usernameService
    ) {
        return args -> {
            for (AppUser user : userRepository.findAll()) {
                boolean changed = false;
                if (user.getCity() == null || user.getCity().isBlank()) {
                    user.setCity(AppUser.DEFAULT_CITY);
                    changed = true;
                }
                if (user.getEquippedAvatarLevel() == null) {
                    user.setEquippedAvatarLevel(1);
                    changed = true;
                }
                if (user.getPublicUsername() == null
                        || user.getPublicUsername().isBlank()) {
                    user.setPublicUsername(usernameService.createUnique(null, user.getEmail()));
                    changed = true;
                }
                if (changed) {
                    userRepository.save(user);
                }
            }

            var legacyEvents = eventRepository.findAllByOrderByEventDateAsc().stream()
                    .filter(event -> event.getCity() == null || event.getCity().isBlank())
                    .peek(event -> {
                        String city = event.getCreator().getCity();
                        event.setCity(city == null || city.isBlank() ? AppUser.DEFAULT_CITY : city);
                        event.setDistrict(event.getCreator().getDistrict() == null ? "Merkez" : event.getCreator().getDistrict());
                        event.setNeighborhood(event.getCreator().getNeighborhood() == null ? "Merkez" : event.getCreator().getNeighborhood());
                        event.setLocation(event.getCity() + ", " + event.getDistrict() + " - " + event.getNeighborhood());
                        event.setImageUrl(null);
                        event.setLatitude(null);
                        event.setLongitude(null);
                    }).toList();
            if (!legacyEvents.isEmpty()) eventRepository.saveAll(legacyEvents);

            String email = "admin@ecovision.com";
            var existingAdmin = userRepository.findByEmail(email);
            if (existingAdmin.isPresent()) {
                AppUser admin = existingAdmin.get();
                if (admin.getAge() == null || admin.getAge() < 18) {
                    admin.setAge(30);
                    userRepository.save(admin);
                }
                return;
            }

            AppUser superuser = new AppUser();
            superuser.setName("EcoVision");
            superuser.setSurname("Süper Kullanıcı");
            superuser.setEmail(email);
            superuser.setPublicUsername(
                    usernameService.createUnique("ecovision_admin", email)
            );
            superuser.setPassword(passwordEncoder.encode("EcoVisionAdmin2026!"));
            superuser.setAge(30);
            superuser.setCity(AppUser.DEFAULT_CITY);
            superuser.setTotalPoints(0);
            superuser.setRole(Role.SUPERUSER);
            userRepository.save(superuser);
        };
    }
}
