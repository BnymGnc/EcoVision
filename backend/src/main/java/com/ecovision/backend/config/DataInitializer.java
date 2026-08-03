package com.ecovision.backend.config;

import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.model.Role;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.service.UsernameService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import java.util.UUID;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

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
                if (user.getEquippedAvatarLevel() == null) {
                    user.setEquippedAvatarLevel(1);
                    changed = true;
                }
                if (user.getPublicUsername() == null
                        || user.getPublicUsername().isBlank()) {
                    user.setPublicUsername(
                            usernameService.createUnique(null, user.getEmail())
                    );
                    changed = true;
                }
                if (changed) {
                    userRepository.save(user);
                }
            }

            var legacyEvents = eventRepository
                    .findAllByOrderByEventDateAsc().stream()
                    .filter(event ->
                            event.getCity() == null || event.getCity().isBlank())
                    .peek(event -> {
                        String city = event.getCreator().getCity();
                        event.setCity(city == null || city.isBlank()
                                ? AppUser.DEFAULT_CITY
                                : city);
                        event.setDistrict(
                                event.getCreator().getDistrict() == null
                                        ? "Merkez"
                                        : event.getCreator().getDistrict()
                        );
                        event.setNeighborhood(
                                event.getCreator().getNeighborhood() == null
                                        ? "Merkez"
                                        : event.getCreator().getNeighborhood()
                        );
                        event.setLocation(
                                event.getCity() + ", " + event.getDistrict()
                                        + " - " + event.getNeighborhood()
                        );
                        event.setImageUrl(null);
                        event.setLatitude(null);
                        event.setLongitude(null);
                    }).toList();
            if (!legacyEvents.isEmpty()) {
                eventRepository.saveAll(legacyEvents);
            }

            String email = "admin@ecovision.com";
            AppUser superuser =
                    userRepository.findByEmail(email).orElseGet(AppUser::new);
            if (superuser.getId() == null) {
                superuser.setName("EcoVision");
                superuser.setSurname("Süper Kullanıcı");
                superuser.setEmail(email);
                superuser.setPublicUsername(
                        usernameService.createUnique("ecovision_admin", email)
                );
                superuser.setPassword(
                        passwordEncoder.encode("EcoVisionAdmin2026!")
                );
                superuser.setTotalPoints(0);
            }
            superuser.setAge(30);
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
            GroupMemberRepository members,
            PlatformTransactionManager transactionManager
    ) {
        return args -> new TransactionTemplate(transactionManager)
                .executeWithoutResult(status -> {
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
                if ((group.getCoverImageUrl() == null
                        || group.getCoverImageUrl().isBlank())
                        && legacy.getCoverImageUrl() != null
                        && !legacy.getCoverImageUrl().isBlank()) {
                    group.setCoverImageUrl(legacy.getCoverImageUrl());
                }
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
                var messages = chatMessages
                        .findByEventIdOrderByTimestampAsc(legacy.getId()).stream()
                        .filter(message -> message.getGroup() == null)
                        .toList();
                messages.forEach(message -> message.setGroup(migratedGroup));
                if (!messages.isEmpty()) {
                    chatMessages.saveAll(messages);
                }
            }

            for (CommunityGroup group : groups.findAll()) {
                if (group.getInviteCode() == null
                        || group.getInviteCode().isBlank()) {
                    group.setInviteCode(
                            UUID.randomUUID().toString()
                                    .replace("-", "")
                                    .substring(0, 16)
                    );
                    groups.save(group);
                }
                boolean passwordProtected =
                        group.getJoinCodeHash() != null
                                && !group.getJoinCodeHash().isBlank();
                group.setPrivateGroup(passwordProtected);
                groups.save(group);
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
        });
    }
}
