package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.MapPin;
import com.ecovision.backend.model.MapPinType;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.repository.MapPinRepository;
import com.ecovision.backend.service.UsernameService;
import java.util.LinkedHashMap;
import java.util.ArrayList;
import java.util.HashMap;
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
    CommandLineRunner migrateLegacyCommunityGroups(
            EventRepository eventRepository,
            EventMemberRepository legacyMembers,
            ChatMessageRepository chatMessages,
            CommunityGroupRepository groups,
            GroupMemberRepository members
    ) {
        return args -> {
            for (var legacy : eventRepository.findAllByOrderByEventDateAsc()) {
                CommunityGroup group = groups.findByLegacyEventId(legacy.getId())
                        .orElseGet(CommunityGroup::new);
                group.setLegacyEventId(legacy.getId());
                group.setCreator(legacy.getCreator());
                group.setName(legacy.getTitle());
                group.setDescription(legacy.getDescription());
                group.setCity(legacy.getCity() == null
                        ? AppUser.DEFAULT_CITY
                        : legacy.getCity());
                group.setDistrict(legacy.getDistrict() == null
                        ? "Merkez"
                        : legacy.getDistrict());
                group.setNeighborhood(legacy.getNeighborhood());
                group.setCoverImageUrl(legacy.getCoverImageUrl());
                group.setMemberLimit(legacy.getMemberLimit());
                group.setJoinCodeHash(legacy.getJoinCodeHash());
                group = groups.save(group);

                for (var legacyMember : legacyMembers
                        .findByEventIdOrderByJoinedAtAsc(legacy.getId())) {
                    if (members.existsByGroupIdAndUserId(
                            group.getId(),
                            legacyMember.getUser().getId()
                    )) {
                        continue;
                    }
                    GroupMember member = new GroupMember();
                    member.setGroup(group);
                    member.setUser(legacyMember.getUser());
                    member.setRole(legacyMember.getRole());
                    members.save(member);
                }
                CommunityGroup migratedGroup = group;
                var messages = chatMessages.findByEventIdOrderByTimestampAsc(
                        legacy.getId()
                ).stream()
                        .filter(message -> message.getGroup() == null)
                        .toList();
                messages.forEach(message -> message.setGroup(migratedGroup));
                if (!messages.isEmpty()) {
                    chatMessages.saveAll(messages);
                }
            }

            for (CommunityGroup group : groups.findAll()) {
                if (!members.existsByGroupIdAndUserId(
                        group.getId(),
                        group.getCreator().getId()
                )) {
                    GroupMember founder = new GroupMember();
                    founder.setGroup(group);
                    founder.setUser(group.getCreator());
                    founder.setRole(GroupRole.FOUNDER);
                    members.save(founder);
                }
            }

            for (GroupMember member : members.findAll()) {
                boolean creator = member.getGroup().getCreator().getId()
                        .equals(member.getUser().getId());
                GroupRole normalizedRole = creator
                        ? GroupRole.FOUNDER
                        : member.getRole() == GroupRole.GROUP_ADMIN
                                ? GroupRole.ADMIN
                                : member.getRole();
                if (member.getRole() != normalizedRole) {
                    member.setRole(normalizedRole);
                    members.save(member);
                }
            }
        };
    }

    @Bean
    @Order(3)
    CommandLineRunner seedRvmMachines(
            AppUserRepository userRepository,
            MapPinRepository mapPinRepository
    ) {
        return args -> {
            AppUser owner = userRepository.findByEmail("admin@ecovision.com")
                    .orElseThrow(() -> new IllegalStateException(
                            "RVM makineleri için süper kullanıcı bulunamadı"
                    ));
            Map<String, MapPin> existingByName = new HashMap<>();
            for (MapPin existing : mapPinRepository.findAll()) {
                existingByName.put(
                        existing.getTitle().toLowerCase(java.util.Locale.ROOT),
                        existing
                );
            }
            List<MapPin> updates = new ArrayList<>();
            for (RvmSeed machine : allMachines()) {
                MapPin pin = existingByName.getOrDefault(
                        machine.name().toLowerCase(java.util.Locale.ROOT),
                        new MapPin()
                );
                pin.setTitle(machine.name());
                pin.setLatitude(machine.latitude());
                pin.setLongitude(machine.longitude());
                pin.setAddress(machine.address());
                pin.setWorkingHours(machine.workingHours());
                pin.setBinStates(machine.binStates());
                pin.setAcceptedMaterials(machine.binStates().entrySet().stream()
                        .filter(entry -> Boolean.TRUE.equals(entry.getValue()))
                        .map(Map.Entry::getKey)
                        .collect(java.util.stream.Collectors.toSet()));
                pin.setActive(true);
                pin.setType(MapPinType.OFFICIAL_RECYCLING_BIN);
                pin.setCreatedBy(owner);
                updates.add(pin);
            }
            mapPinRepository.saveAll(updates);
        };
    }

    private List<RvmSeed> allMachines() {
        return java.util.stream.Stream.concat(
                kayseriMachines().stream(),
                sanliurfaMachines().stream()
        ).toList();
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
        return new RvmSeed(name, lat, lng, address, null, Map.of());
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
        return new RvmSeed(name, lat, lng, address, null, states);
    }

    private RvmSeed rvm(
            String name,
            double lat,
            double lng,
            String address,
            String workingHours
    ) {
        Map<String, Boolean> states = new LinkedHashMap<>();
        states.put("pet", true);
        states.put("glass", true);
        states.put("aluminum", true);
        return new RvmSeed(name, lat, lng, address, workingHours, states);
    }

    private List<RvmSeed> sanliurfaMachines() {
        return List.of(
                rvm("MİGROS MJET ŞANLIURFA POLDEM", 37.169498, 38.801101,
                        "Selahaddin Eyyübi Mah. 218 Sokak No:14/1 Şanlıurfa/Haliliye",
                        "09:00 - 22:00"),
                rvm("A101 I678 İSTİKLAL", 37.173198, 38.814094,
                        "Veysel Karani Mah. 361. Sokak No:1/0 Şanlıurfa/Haliliye",
                        "09:00 - 21:00"),
                rvm("BİM-SELÇUKLU/HALİLİYE", 37.170852, 38.765319,
                        "Devteyşti Mah. 9629 Sok. No:18/1 Şanlıurfa/Haliliye",
                        "09:00 - 21:00"),
                rvm("MİGROS GÜZELŞEHİR KARAKÖPRÜ", 37.201103, 38.817825,
                        "Doğukent Mah. Fatih Sultan Mehmet Blv. No:3/A-B Şanlıurfa/Karaköprü",
                        "09:00 - 22:00"),
                rvm("A101 C348 EVREN", 37.138927, 38.739139,
                        "Batıkent Mah. 4168 Sokak No:2/0 Şanlıurfa/Eyyübiye",
                        "09:00 - 21:00"),
                rvm("BİM-ZİRAAT FAK./EYYÜBİYE", 37.119987, 38.815246,
                        "Hayati Harrani Mah. Akçakale Cad. No:408/1 Şanlıurfa/Eyyübiye",
                        "09:00 - 21:00"),
                rvm("A101 6526 11 NİSAN", 36.977809, 38.425064,
                        "Cumhuriyet Mah. 11 Nisan Caddesi No:14/0 Şanlıurfa/Suruç",
                        "09:00 - 21:00"),
                rvm("BİM-ALİGÖR/SURUÇ", 36.975120, 38.424285,
                        "Aligör Mah. Cumhuriyet Caddesi No:9/1 Şanlıurfa/Suruç",
                        "09:00 - 21:00"),
                rvm("BİM-15 TEMMUZ/AKÇAKALE", 36.713348, 38.948440,
                        "Fevzi Çakmak Mah. Abdullah Gül Bulvarı No:52/1 Şanlıurfa/Akçakale",
                        "09:00 - 21:00"),
                rvm("A101 C819 FEVZİ ÇAKMAK", 36.713348, 38.948440,
                        "Fevzi Çakmak Mah. Abdullah Gül Bulvarı No:52/0 Şanlıurfa/Akçakale",
                        "09:00 - 21:00"),
                rvm("A101 J401 KERVAN", 36.862697, 39.017734,
                        "Cumhuriyet Mah. Necmettin Cevheri Mah. No:1/1 Şanlıurfa/Harran",
                        "09:00 - 21:00"),
                rvm("BİM-BORSA/HARRAN", 36.863132, 39.024276,
                        "Hz. Yakup Mah. Yatılı Bölge Okulu Cad. No:15/A/1 Şanlıurfa/Harran",
                        "09:00 - 21:00"),
                rvm("A101 - 3903 15 TEMMUZ", 36.853008, 40.046833,
                        "Cumhuriyet Mah. 1009 Sokak No:-/- Şanlıurfa/Ceylanpınar",
                        "09:00 - 21:00"),
                rvm("BİM-YILDIZ/CEYLANPINAR", 36.853057, 40.047397,
                        "15 Temmuz Mah. 429.Sok. No:8/1 Şanlıurfa/Ceylanpınar",
                        "09:00 - 21:00")
        );
    }

    private record RvmSeed(
            String name,
            double latitude,
            double longitude,
            String address,
            String workingHours,
            Map<String, Boolean> binStates
    ) {
    }
}
