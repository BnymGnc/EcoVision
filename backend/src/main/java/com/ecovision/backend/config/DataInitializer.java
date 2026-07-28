package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.ecovision.backend.service.UsernameService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataInitializer {
    @Bean
    @Order(1)
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
                if (user.getPublicUsername() == null || user.getPublicUsername().isBlank()) {
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
                        event.setCity(city == null || city.isBlank()
                                ? AppUser.DEFAULT_CITY
                                : city);
                        event.setDistrict(event.getCreator().getDistrict() == null
                                ? "Merkez"
                                : event.getCreator().getDistrict());
                        event.setNeighborhood(event.getCreator().getNeighborhood() == null
                                ? "Merkez"
                                : event.getCreator().getNeighborhood());
                        event.setLocation(event.getCity() + ", " + event.getDistrict()
                                + " - " + event.getNeighborhood());
                        event.setImageUrl(null);
                        event.setLatitude(null);
                        event.setLongitude(null);
                    }).toList();
            if (!legacyEvents.isEmpty()) {
                eventRepository.saveAll(legacyEvents);
            }

            String email = "admin@ecovision.com";
            AppUser superuser = userRepository.findByEmail(email).orElseGet(AppUser::new);
            if (superuser.getId() == null) {
                superuser.setName("EcoVision");
                superuser.setSurname("Süper Kullanıcı");
                superuser.setEmail(email);
                superuser.setPublicUsername(
                        usernameService.createUnique("ecovision_admin", email)
                );
                superuser.setPassword(passwordEncoder.encode("EcoVisionAdmin2026!"));
                superuser.setTotalPoints(0);
            }
            superuser.setAge(30);
            superuser.setCity(AppUser.DEFAULT_CITY);
            superuser.setRole(Role.SUPERUSER);
            userRepository.save(superuser);
        };
    }

    @Bean
    @Order(2)
    CommandLineRunner seedKayseriRvmMachines(
            AppUserRepository userRepository,
            MapPinRepository mapPinRepository
    ) {
        return args -> {
            AppUser owner = userRepository.findByEmail("admin@ecovision.com")
                    .orElseThrow(() -> new IllegalStateException(
                            "RVM makineleri için süper kullanıcı bulunamadı"
                    ));
            for (RvmSeed machine : kayseriMachines()) {
                MapPin pin = mapPinRepository.findFirstByTitleIgnoreCase(machine.name())
                        .orElseGet(MapPin::new);
                pin.setTitle(machine.name());
                pin.setLatitude(machine.latitude());
                pin.setLongitude(machine.longitude());
                pin.setAddress(machine.address());
                pin.setWorkingHours(null);
                pin.setBinStates(machine.binStates());
                pin.setAcceptedMaterials(machine.binStates().entrySet().stream()
                        .filter(entry -> Boolean.TRUE.equals(entry.getValue()))
                        .map(Map.Entry::getKey)
                        .collect(java.util.stream.Collectors.toSet()));
                pin.setActive(true);
                pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
                pin.setCreatedBy(owner);
                mapPinRepository.save(pin);
            }
        };
    }

    private List<RvmSeed> kayseriMachines() {
        return List.of(
                rvm("MİGROS FEVZİ ÇAKMAK", 38.731273, 35.502796,
                        "FEVZİ ÇAKMAK MAH YEŞİLIRMAK CADDE No:46",
                        false, false, true),
                rvm("MİGROS SİVAS BULVARI", 38.733482, 35.531169,
                        "YILDIRIM BEYAZIT MAH SİVAS BULVAR No:200/A",
                        false, false, true),
                rvm("A101 I436 TİMUÇİN", 38.702713, 35.557172,
                        "MEVLANA MAH MEHMET TİMUÇİN CADDE No:66B"),
                rvm("MİGROS ANAŞEHİR TALAS", 38.704334, 35.558917,
                        "MEVLANA MAH VELİOĞLU CAD. No:16",
                        true, true, true),
                rvm("BİM-TARİF", 38.713047, 35.565433,
                        "MEVLANA MAH Şht. Fatih Duman Sk. No:17 B/1",
                        true, true, true),
                rvm("A101 0556 ÖZGÜVEN", 38.701534, 35.439880,
                        "ALTINOLUK MAH VEYSEL CADDE No:9A",
                        true, true, true),
                rvm("A101 G881 TEPECİK", 38.790377, 35.461078,
                        "OSMANGAZİ MAH 49. SOKAK No:32/2"),
                rvm("V047 BİM DERE", 38.795898, 35.449037,
                        "ERKİLET MAH Lale Paşa Sk. No:8/1",
                        true, true, true),
                rvm("A101 3310 HACILAR", 38.648574, 35.452331,
                        "YENİ MAH ÇAVUŞOĞLU CADDE No:18A",
                        false, true, true),
                rvm("BİM-Hacılar", 38.645980, 35.452556,
                        "YUKARI MAH Şehit Rüştü bayram cad No:18",
                        true, true, true),
                rvm("BİM-DERGAH", 38.784172, 35.606895,
                        "GESİ FATİH MAH Hanedan Sk. No:11 A/1",
                        true, true, true),
                rvm("BİM-ÖZVATAN", 38.782387, 35.609003,
                        "CUMHURİYET MAH Hasan Ünal Cad No:8 A/1",
                        true, true, true)
        );
    }

    private RvmSeed rvm(String name, double lat, double lng, String address) {
        return new RvmSeed(name, lat, lng, address, Map.of());
    }

    private RvmSeed rvm(
            String name,
            double lat,
            double lng,
            String address,
            boolean pet,
            boolean glass,
            boolean aluminum
    ) {
        Map<String, Boolean> states = new LinkedHashMap<>();
        states.put("pet", pet);
        states.put("glass", glass);
        states.put("aluminum", aluminum);
        return new RvmSeed(name, lat, lng, address, states);
    }

    private record RvmSeed(
            String name,
            double latitude,
            double longitude,
            String address,
            Map<String, Boolean> binStates
    ) {
    }
}
