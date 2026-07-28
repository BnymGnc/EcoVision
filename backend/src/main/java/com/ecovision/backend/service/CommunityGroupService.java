package com.ecovision.backend.service;

import com.ecovision.backend.dto.CommunityGroupRequest;
import com.ecovision.backend.dto.CommunityGroupResponse;
import com.ecovision.backend.dto.EventRsvpRequest;
import com.ecovision.backend.dto.GroupEventAttendeeResponse;
import com.ecovision.backend.dto.GroupEventRequest;
import com.ecovision.backend.dto.GroupEventResponse;
import com.ecovision.backend.dto.GroupMemberResponse;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AttendanceStatus;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupEvent;
import com.ecovision.backend.model.GroupEventAttendance;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.GroupEventAttendanceRepository;
import com.ecovision.backend.repository.GroupEventRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CommunityGroupService {
    private final CommunityGroupRepository groups;
    private final GroupMemberRepository members;
    private final GroupEventRepository events;
    private final GroupEventAttendanceRepository attendance;
    private final ChatMessageRepository chatMessages;
    private final AgeGateService ageGate;
    private final InputSanitizer sanitizer;
    private final FileStorageService storage;
    private final PasswordEncoder passwordEncoder;

    public CommunityGroupService(
            CommunityGroupRepository groups,
            GroupMemberRepository members,
            GroupEventRepository events,
            GroupEventAttendanceRepository attendance,
            ChatMessageRepository chatMessages,
            AgeGateService ageGate,
            InputSanitizer sanitizer,
            FileStorageService storage,
            PasswordEncoder passwordEncoder
    ) {
        this.groups = groups;
        this.members = members;
        this.events = events;
        this.attendance = attendance;
        this.chatMessages = chatMessages;
        this.ageGate = ageGate;
        this.sanitizer = sanitizer;
        this.storage = storage;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public List<CommunityGroupResponse> list(
            AppUser user,
            String query,
            String cities,
            String district
    ) {
        ageGate.requireAdult(user);
        String normalizedQuery = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        Set<String> selectedCities = Arrays.stream(
                        cities == null ? new String[0] : cities.split(",")
                )
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(value -> value.toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());
        String selectedDistrict = district == null
                ? ""
                : district.trim().toLowerCase(Locale.ROOT);

        return groups.findAll().stream()
                .filter(group -> normalizedQuery.isBlank()
                        || group.getName().toLowerCase(Locale.ROOT).contains(normalizedQuery)
                        || group.getDescription().toLowerCase(Locale.ROOT).contains(normalizedQuery))
                .filter(group -> selectedCities.isEmpty()
                        || selectedCities.contains(group.getCity().toLowerCase(Locale.ROOT)))
                .filter(group -> selectedDistrict.isBlank()
                        || group.getDistrict().equalsIgnoreCase(selectedDistrict))
                .map(group -> response(group, user))
                .toList();
    }

    @Transactional(readOnly = true)
    public CommunityGroupResponse get(AppUser user, Long groupId) {
        ageGate.requireAdult(user);
        return response(findGroup(groupId), user);
    }

    @Transactional
    public CommunityGroupResponse create(
            AppUser user,
            CommunityGroupRequest request,
            MultipartFile cover
    ) {
        ageGate.requireAdult(user);
        CommunityGroup group = new CommunityGroup();
        group.setCreator(user);
        group.setName(required(request.name(), "Grup adı", 120));
        group.setDescription(required(request.description(), "Açıklama", 2000));
        group.setCity(required(request.city(), "İl", 80));
        group.setDistrict(required(request.district(), "İlçe", 80));
        group.setNeighborhood(sanitizer.plainText(
                request.neighborhood(),
                "Mahalle",
                120
        ));
        group.setMemberLimit(request.memberLimit() == null ? 20 : request.memberLimit());
        if (request.joinCode() != null && !request.joinCode().isBlank()) {
            group.setJoinCodeHash(passwordEncoder.encode(request.joinCode().trim()));
        }
        if (cover != null && !cover.isEmpty()) {
            group.setCoverImageUrl(storage.storeImage(cover, "groups"));
        }
        group = groups.save(group);

        GroupMember owner = new GroupMember();
        owner.setGroup(group);
        owner.setUser(user);
        owner.setRole(GroupRole.GROUP_ADMIN);
        members.save(owner);
        return response(group, user);
    }

    @Transactional
    public CommunityGroupResponse join(
            AppUser user,
            Long groupId,
            JoinEventRequest request
    ) {
        ageGate.requireAdult(user);
        CommunityGroup group = findGroup(groupId);
        if (members.existsByGroupIdAndUserId(groupId, user.getId())) {
            return response(group, user);
        }
        if (members.countByGroupId(groupId) >= group.getMemberLimit()) {
            throw new IllegalArgumentException("Grup üye sınırına ulaştı");
        }
        if (group.isPrivateGroup()) {
            String code = request == null ? null : request.joinCode();
            if (code == null || !passwordEncoder.matches(code, group.getJoinCodeHash())) {
                throw new IllegalArgumentException("Grup parolası hatalı");
            }
        }
        GroupMember member = new GroupMember();
        member.setGroup(group);
        member.setUser(user);
        member.setRole(GroupRole.MEMBER);
        members.save(member);
        return response(group, user);
    }

    @Transactional(readOnly = true)
    public List<GroupMemberResponse> members(AppUser user, Long groupId) {
        requireMember(user, groupId);
        return members.findByGroupIdOrderByJoinedAtAsc(groupId).stream()
                .map(GroupMemberResponse::from)
                .toList();
    }

    @Transactional
    public GroupMemberResponse promote(AppUser user, Long groupId, Long userId) {
        requireAdmin(user, groupId);
        GroupMember member = members.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi bulunamadı"));
        member.setRole(GroupRole.GROUP_ADMIN);
        return GroupMemberResponse.from(members.save(member));
    }

    @Transactional
    public void removeMember(AppUser user, Long groupId, Long userId) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        if (group.getCreator().getId().equals(userId)) {
            throw new IllegalArgumentException("Grup kurucusu gruptan çıkarılamaz");
        }
        GroupMember member = members.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi bulunamadı"));
        members.delete(member);
    }

    @Transactional(readOnly = true)
    public List<GroupEventResponse> upcomingEvents(AppUser user, Long groupId) {
        requireMember(user, groupId);
        return events.findByGroupIdAndEventDateGreaterThanEqualOrderByEventDateAsc(
                        groupId,
                        Instant.now()
                ).stream()
                .map(event -> eventResponse(event, user))
                .toList();
    }

    @Transactional
    public GroupEventResponse createEvent(
            AppUser user,
            Long groupId,
            GroupEventRequest request,
            MultipartFile cover
    ) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        GroupEvent event = new GroupEvent();
        event.setGroup(group);
        event.setCreator(user);
        event.setTitle(required(request.title(), "Etkinlik adı", 140));
        event.setDescription(required(request.description(), "Açıklama", 2000));
        event.setEventDate(request.eventDate());
        event.setCity(required(request.city(), "İl", 80));
        event.setDistrict(required(request.district(), "İlçe", 80));
        event.setExactAddress(required(request.exactAddress(), "Adres", 500));
        if (cover != null && !cover.isEmpty()) {
            event.setCoverImageUrl(storage.storeImage(cover, "group-events"));
        }
        return eventResponse(events.save(event), user);
    }

    @Transactional
    public GroupEventResponse rsvp(
            AppUser user,
            Long groupId,
            Long eventId,
            EventRsvpRequest request
    ) {
        requireMember(user, groupId);
        GroupEvent event = findEvent(groupId, eventId);
        AttendanceStatus status = request.status();
        GroupEventAttendance answer = attendance.findByEventIdAndUserId(eventId, user.getId())
                .orElseGet(GroupEventAttendance::new);
        answer.setEvent(event);
        answer.setUser(user);
        answer.setStatus(status);
        attendance.save(answer);
        return eventResponse(event, user);
    }

    @Transactional(readOnly = true)
    public List<GroupEventAttendeeResponse> attendees(
            AppUser user,
            Long groupId,
            Long eventId
    ) {
        requireMember(user, groupId);
        findEvent(groupId, eventId);
        return attendance.findByEventIdAndStatusOrderByRespondedAtAsc(
                        eventId,
                        AttendanceStatus.ATTENDING
                ).stream()
                .map(GroupEventAttendeeResponse::from)
                .toList();
    }

    @Transactional
    public void deleteEvent(AppUser user, Long groupId, Long eventId) {
        requireAdmin(user, groupId);
        GroupEvent event = findEvent(groupId, eventId);
        attendance.deleteByEventId(eventId);
        events.delete(event);
    }

    @Transactional
    public void deleteGroup(AppUser user, Long groupId) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        if (!group.getCreator().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Grubu yalnızca kurucusu silebilir");
        }
        for (GroupEvent event : events
                .findByGroupIdAndEventDateGreaterThanEqualOrderByEventDateAsc(
                        groupId,
                        Instant.EPOCH
                )) {
            attendance.deleteByEventId(event.getId());
        }
        chatMessages.deleteByGroupId(groupId);
        events.deleteByGroupId(groupId);
        members.deleteByGroupId(groupId);
        groups.delete(group);
    }

    private CommunityGroupResponse response(CommunityGroup group, AppUser user) {
        String role = members.findByGroupIdAndUserId(group.getId(), user.getId())
                .map(member -> member.getRole().name())
                .orElse(null);
        return CommunityGroupResponse.from(
                group,
                members.countByGroupId(group.getId()),
                role
        );
    }

    private GroupEventResponse eventResponse(GroupEvent event, AppUser user) {
        String currentAttendance = attendance
                .findByEventIdAndUserId(event.getId(), user.getId())
                .map(answer -> answer.getStatus().name())
                .orElse(null);
        return GroupEventResponse.from(
                event,
                attendance.countByEventIdAndStatus(
                        event.getId(),
                        AttendanceStatus.ATTENDING
                ),
                currentAttendance
        );
    }

    private CommunityGroup findGroup(Long groupId) {
        return groups.findById(groupId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
    }

    private GroupEvent findEvent(Long groupId, Long eventId) {
        GroupEvent event = events.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Etkinlik bulunamadı"));
        if (!event.getGroup().getId().equals(groupId)) {
            throw new IllegalArgumentException("Etkinlik bu gruba ait değil");
        }
        return event;
    }

    private void requireMember(AppUser user, Long groupId) {
        ageGate.requireAdult(user);
        if (!members.existsByGroupIdAndUserId(groupId, user.getId())) {
            throw new IllegalArgumentException("Bu işlem yalnızca grup üyelerine açıktır");
        }
    }

    private void requireAdmin(AppUser user, Long groupId) {
        ageGate.requireAdult(user);
        GroupMember member = members.findByGroupIdAndUserId(groupId, user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi değilsiniz"));
        if (member.getRole() != GroupRole.GROUP_ADMIN) {
            throw new IllegalArgumentException("Bu işlem için grup yöneticisi olmalısınız");
        }
    }

    private String required(String value, String field, int maxLength) {
        String clean = sanitizer.plainText(value, field, maxLength);
        if (clean == null || clean.isBlank()) {
            throw new IllegalArgumentException(field + " zorunludur");
        }
        return clean;
    }
}
