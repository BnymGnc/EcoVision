package com.ecovision.backend.service;

import com.ecovision.backend.dto.AddGroupMemberRequest;
import com.ecovision.backend.dto.CommunityGroupRequest;
import com.ecovision.backend.dto.CommunityGroupResponse;
import com.ecovision.backend.dto.ChatMessageResponse;
import com.ecovision.backend.dto.EventRsvpRequest;
import com.ecovision.backend.dto.GroupEventAttendeeResponse;
import com.ecovision.backend.dto.GroupEventRequest;
import com.ecovision.backend.dto.GroupEventResponse;
import com.ecovision.backend.dto.GroupMemberResponse;
import com.ecovision.backend.dto.GroupJoinRequestResponse;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.dto.PinGroupContentRequest;
import com.ecovision.backend.dto.UpdateCommunityGroupRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AttendanceStatus;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.CommunityGroup;
import com.ecovision.backend.model.GroupEvent;
import com.ecovision.backend.model.GroupEventAttendance;
import com.ecovision.backend.model.GroupMember;
import com.ecovision.backend.model.GroupJoinRequest;
import com.ecovision.backend.model.GroupJoinRequestStatus;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.repository.AppUserRepository;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.CommunityGroupRepository;
import com.ecovision.backend.repository.GroupEventAttendanceRepository;
import com.ecovision.backend.repository.GroupEventRepository;
import com.ecovision.backend.repository.GroupMemberRepository;
import com.ecovision.backend.repository.GroupJoinRequestRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CommunityGroupService {
    private final CommunityGroupRepository groups;
    private final AppUserRepository users;
    private final GroupMemberRepository members;
    private final GroupEventRepository events;
    private final GroupEventAttendanceRepository attendance;
    private final ChatMessageRepository chatMessages;
    private final AgeGateService ageGate;
    private final InputSanitizer sanitizer;
    private final FileStorageService storage;
    private final PasswordEncoder passwordEncoder;
    private final RealtimeChatPublisher realtimePublisher;
    private final GroupJoinRequestRepository joinRequests;

    public CommunityGroupService(
            CommunityGroupRepository groups,
            AppUserRepository users,
            GroupMemberRepository members,
            GroupEventRepository events,
            GroupEventAttendanceRepository attendance,
            ChatMessageRepository chatMessages,
            AgeGateService ageGate,
            InputSanitizer sanitizer,
            FileStorageService storage,
            PasswordEncoder passwordEncoder,
            RealtimeChatPublisher realtimePublisher,
            GroupJoinRequestRepository joinRequests
    ) {
        this.groups = groups;
        this.users = users;
        this.members = members;
        this.events = events;
        this.attendance = attendance;
        this.chatMessages = chatMessages;
        this.ageGate = ageGate;
        this.sanitizer = sanitizer;
        this.storage = storage;
        this.passwordEncoder = passwordEncoder;
        this.realtimePublisher = realtimePublisher;
        this.joinRequests = joinRequests;
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
                        || normalized(group.getName()).contains(normalizedQuery)
                        || normalized(group.getDescription()).contains(normalizedQuery))
                .filter(group -> selectedCities.isEmpty()
                        || selectedCities.contains(normalized(group.getCity())))
                .filter(group -> selectedDistrict.isBlank()
                        || normalized(group.getDistrict()).equals(selectedDistrict))
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
        group.setPrivateGroup(Boolean.TRUE.equals(request.privateGroup()));
        if (request.joinCode() != null && !request.joinCode().isBlank()) {
            group.setJoinCodeHash(passwordEncoder.encode(request.joinCode().trim()));
            group.setPrivateGroup(true);
        }
        if (cover != null && !cover.isEmpty()) {
            group.setCoverImageUrl(storage.storeImage(cover, "groups"));
        }
        group = groups.save(group);

        GroupMember owner = new GroupMember();
        owner.setGroup(group);
        owner.setUser(user);
        owner.setRole(GroupRole.FOUNDER);
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
        int memberLimit = group.getMemberLimit() == null
                ? 20
                : group.getMemberLimit();
        if (members.countByGroupId(groupId) >= memberLimit) {
            throw new IllegalArgumentException("Grup üye sınırına ulaştı");
        }
        if (group.isPrivateGroup()) {
            String code = request == null ? null : request.joinCode();
            boolean legacyPasswordValid = group.getJoinCodeHash() != null
                    && code != null
                    && passwordEncoder.matches(code, group.getJoinCodeHash());
            boolean inviteCodeValid = code != null
                    && code.equalsIgnoreCase(group.getInviteCode());
            if (!legacyPasswordValid && !inviteCodeValid) {
                throw new IllegalArgumentException(
                        "Bu özel grup için katılım isteği göndermelisiniz"
                );
            }
        }
        GroupMember member = new GroupMember();
        member.setGroup(group);
        member.setUser(user);
        member.setRole(GroupRole.MEMBER);
        members.save(member);
        publishSystem(group, user, user.getName() + " gruba katıldı");
        return response(group, user);
    }

    @Transactional
    public GroupJoinRequestResponse requestToJoin(AppUser user, Long groupId) {
        ageGate.requireAdult(user);
        CommunityGroup group = findGroup(groupId);
        if (!group.isPrivateGroup()) {
            throw new IllegalArgumentException(
                    "Grup herkese açık; doğrudan katılabilirsiniz"
            );
        }
        if (members.existsByGroupIdAndUserId(groupId, user.getId())) {
            throw new IllegalArgumentException("Zaten bu grubun üyesisiniz");
        }
        GroupJoinRequest request = joinRequests
                .findByGroupIdAndRequesterId(groupId, user.getId())
                .orElseGet(GroupJoinRequest::new);
        request.setGroup(group);
        request.setRequester(user);
        request.setStatus(GroupJoinRequestStatus.PENDING);
        request.setRespondedAt(null);
        return GroupJoinRequestResponse.from(joinRequests.save(request));
    }

    @Transactional(readOnly = true)
    public List<GroupJoinRequestResponse> pendingRequests(
            AppUser user,
            Long groupId
    ) {
        requireAdmin(user, groupId);
        return joinRequests.findByGroupIdAndStatusOrderByRequestedAtAsc(
                        groupId,
                        GroupJoinRequestStatus.PENDING
                ).stream()
                .map(GroupJoinRequestResponse::from)
                .toList();
    }

    @Transactional
    public GroupJoinRequestResponse reviewJoinRequest(
            AppUser user,
            Long groupId,
            Long requestId,
            boolean approve
    ) {
        requireAdmin(user, groupId);
        GroupJoinRequest request = joinRequests.findById(requestId)
                .filter(item -> item.getGroup().getId().equals(groupId))
                .orElseThrow(() -> new IllegalArgumentException(
                        "Katılım isteği bulunamadı"
                ));
        if (request.getStatus() != GroupJoinRequestStatus.PENDING) {
            throw new IllegalArgumentException("Katılım isteği daha önce sonuçlandırılmış");
        }
        if (approve) {
            CommunityGroup group = request.getGroup();
            if (members.countByGroupId(groupId) >= group.getMemberLimit()) {
                throw new IllegalArgumentException("Grup üye sınırına ulaştı");
            }
            if (!members.existsByGroupIdAndUserId(
                    groupId,
                    request.getRequester().getId()
            )) {
                GroupMember member = new GroupMember();
                member.setGroup(group);
                member.setUser(request.getRequester());
                member.setRole(GroupRole.MEMBER);
                members.save(member);
                publishSystem(
                        group,
                        user,
                        request.getRequester().getName() + " gruba katıldı"
                );
            }
        }
        request.setStatus(
                approve
                        ? GroupJoinRequestStatus.APPROVED
                        : GroupJoinRequestStatus.REJECTED
        );
        request.setRespondedAt(Instant.now());
        return GroupJoinRequestResponse.from(joinRequests.save(request));
    }

    @Transactional
    public CommunityGroupResponse update(
            AppUser user,
            Long groupId,
            UpdateCommunityGroupRequest request,
            MultipartFile cover
    ) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        group.setName(required(request.name(), "Grup adı", 120));
        group.setDescription(required(request.description(), "Açıklama", 2000));
        group.setCity(required(request.city(), "İl", 80));
        group.setDistrict(required(request.district(), "İlçe", 80));
        group.setNeighborhood(sanitizer.plainText(
                request.neighborhood(),
                "Mahalle",
                120
        ));
        group.setMemberLimit(
                request.memberLimit() == null
                        ? group.getMemberLimit()
                        : request.memberLimit()
        );
        if (request.privateGroup() != null) {
            group.setPrivateGroup(request.privateGroup());
        }
        if (cover != null && !cover.isEmpty()) {
            group.setCoverImageUrl(storage.storeImage(cover, "groups"));
        }
        return response(groups.save(group), user);
    }

    @Transactional(readOnly = true)
    public List<GroupMemberResponse> members(AppUser user, Long groupId) {
        requireMember(user, groupId);
        CommunityGroup group = findGroup(groupId);
        return members.findByGroupIdOrderByJoinedAtAsc(groupId).stream()
                .map(member -> memberResponse(member, group))
                .toList();
    }

    @Transactional
    public GroupMemberResponse addMember(
            AppUser user,
            Long groupId,
            AddGroupMemberRequest request
    ) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        AppUser target = users.findByPublicUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı"));
        ageGate.requireAdult(target);
        if (members.existsByGroupIdAndUserId(groupId, target.getId())) {
            throw new IllegalArgumentException("Kullanıcı zaten bu grubun üyesi");
        }
        int memberLimit = group.getMemberLimit() == null
                ? 20
                : group.getMemberLimit();
        if (members.countByGroupId(groupId) >= memberLimit) {
            throw new IllegalArgumentException("Grup üye sınırına ulaştı");
        }
        GroupMember member = new GroupMember();
        member.setGroup(group);
        member.setUser(target);
        member.setRole(GroupRole.MEMBER);
        GroupMember saved = members.save(member);
        publishSystem(group, user, target.getName() + " gruba eklendi");
        return GroupMemberResponse.from(saved);
    }

    @Transactional
    public GroupMemberResponse promote(AppUser user, Long groupId, Long userId) {
        requireFounder(user, groupId);
        CommunityGroup group = findGroup(groupId);
        GroupMember member = findMember(groupId, userId);
        if (isFounder(member, group)) {
            throw new IllegalArgumentException("Grup kurucusunun rolü değiştirilemez");
        }
        member.setRole(GroupRole.ADMIN);
        GroupMember saved = members.save(member);
        publishSystem(
                group,
                user,
                member.getUser().getName() + " yönetici yapıldı"
        );
        return GroupMemberResponse.from(saved);
    }

    @Transactional
    public GroupMemberResponse demote(AppUser user, Long groupId, Long userId) {
        requireFounder(user, groupId);
        CommunityGroup group = findGroup(groupId);
        GroupMember member = findMember(groupId, userId);
        if (isFounder(member, group)) {
            throw new IllegalArgumentException("Grup kurucusunun rolü değiştirilemez");
        }
        if (!isAdmin(member.getRole())) {
            throw new IllegalArgumentException("Bu kullanıcı yönetici değil");
        }
        member.setRole(GroupRole.MEMBER);
        GroupMember saved = members.save(member);
        publishSystem(
                group,
                user,
                member.getUser().getName() + " üyeliğe geçirildi"
        );
        return GroupMemberResponse.from(saved);
    }

    @Transactional
    public void removeMember(AppUser user, Long groupId, Long userId) {
        CommunityGroup group = findGroup(groupId);
        GroupMember actor = requireMemberRecord(user, groupId);
        GroupMember target = findMember(groupId, userId);
        if (isFounder(target, group)) {
            throw new AccessDeniedException("Grup kurucusu gruptan çıkarılamaz");
        }
        if (isFounder(actor, group)) {
            members.delete(target);
            publishSystem(
                    group,
                    user,
                    target.getUser().getName() + " gruptan çıkarıldı"
            );
            return;
        }
        if (!isAdmin(actor.getRole()) || target.getRole() != GroupRole.MEMBER) {
            throw new AccessDeniedException(
                    "Yöneticiler yalnızca normal üyeleri gruptan çıkarabilir"
            );
        }
        members.delete(target);
        publishSystem(
                group,
                user,
                target.getUser().getName() + " gruptan çıkarıldı"
        );
    }

    @Transactional
    public void leaveGroup(AppUser user, Long groupId) {
        CommunityGroup group = findGroup(groupId);
        GroupMember member = requireMemberRecord(user, groupId);
        if (isFounder(member, group)) {
            throw new AccessDeniedException(
                    "Kurucu gruptan ayrılamaz; önce grubu silmelisiniz"
            );
        }
        members.delete(member);
        publishSystem(group, user, user.getName() + " gruptan ayrıldı");
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
        event.setCapacity(request.capacity() == null ? 20 : request.capacity());
        if (cover != null && !cover.isEmpty()) {
            event.setCoverImageUrl(storage.storeImage(cover, "group-events"));
        }
        event = events.save(event);

        ChatMessage announcement = new ChatMessage();
        announcement.setGroup(group);
        announcement.setGroupEvent(event);
        announcement.setSender(user);
        announcement.setMessage("Yeni etkinlik: " + event.getTitle());
        announcement.setMessageType(ChatMessageType.SYSTEM_EVENT);
        ChatMessageResponse announcementResponse =
                ChatMessageResponse.from(chatMessages.save(announcement));
        realtimePublisher.publishAfterCommit(announcementResponse);
        return eventResponse(event, user);
    }

    @Transactional
    public GroupEventResponse rsvp(
            AppUser user,
            Long groupId,
            Long eventId,
            EventRsvpRequest request
    ) {
        requireMember(user, groupId);
        GroupEvent event = events.findByIdForUpdate(groupId, eventId)
                .orElseThrow(() -> new IllegalArgumentException("Etkinlik bulunamadı"));
        AttendanceStatus status = request.status();
        GroupEventAttendance answer = attendance
                .findByEventIdAndUserId(eventId, user.getId())
                .orElseGet(GroupEventAttendance::new);
        boolean firstJoin = answer.getId() == null
                || answer.getStatus() != AttendanceStatus.ATTENDING;
        if (status == AttendanceStatus.ATTENDING
                && firstJoin
                && attendance.countByEventIdAndStatus(
                        eventId,
                        AttendanceStatus.ATTENDING
                ) >= event.getCapacity()) {
            throw new IllegalArgumentException("Etkinlik kontenjanı dolu");
        }
        answer.setEvent(event);
        answer.setUser(user);
        answer.setStatus(status);
        attendance.save(answer);
        return eventResponse(event, user);
    }

    @Transactional
    public GroupEventResponse leaveEvent(AppUser user, Long groupId, Long eventId) {
        requireMember(user, groupId);
        GroupEvent event = findEvent(groupId, eventId);
        attendance.deleteByEventIdAndUserId(eventId, user.getId());
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
        return attendeeResponses(eventId);
    }

    @Transactional
    public CommunityGroupResponse pinContent(
            AppUser user,
            Long groupId,
            PinGroupContentRequest request
    ) {
        requireAdmin(user, groupId);
        CommunityGroup group = findGroup(groupId);
        switch (request.type()) {
            case "MESSAGE" -> {
                if (request.id() == null) {
                    throw new IllegalArgumentException("Mesaj kimliği zorunludur");
                }
                chatMessages.findByIdAndGroupId(request.id(), groupId)
                        .orElseThrow(() -> new IllegalArgumentException("Mesaj bulunamadı"));
                group.setPinnedMessageId(request.id());
                group.setPinnedEventId(null);
            }
            case "EVENT" -> {
                if (request.id() == null) {
                    throw new IllegalArgumentException("Etkinlik kimliği zorunludur");
                }
                findEvent(groupId, request.id());
                group.setPinnedEventId(request.id());
                group.setPinnedMessageId(null);
            }
            case "NONE" -> {
                group.setPinnedEventId(null);
                group.setPinnedMessageId(null);
            }
            default -> throw new IllegalArgumentException("Geçersiz sabitleme türü");
        }
        CommunityGroup saved = groups.save(group);
        if (!"NONE".equals(request.type())) {
            publishSystem(group, user, user.getName() + " bir içeriği sabitledi");
        }
        return response(saved, user);
    }

    @Transactional
    public void deleteEvent(AppUser user, Long groupId, Long eventId) {
        requireAdmin(user, groupId);
        GroupEvent event = findEvent(groupId, eventId);
        attendance.deleteByEventId(eventId);
        chatMessages.deleteByGroupEventId(eventId);
        CommunityGroup group = event.getGroup();
        if (eventId.equals(group.getPinnedEventId())) {
            group.setPinnedEventId(null);
            groups.save(group);
        }
        events.delete(event);
    }

    @Transactional
    public void deleteGroup(AppUser user, Long groupId) {
        requireFounder(user, groupId);
        CommunityGroup group = findGroup(groupId);
        for (GroupEvent event : events
                .findByGroupIdAndEventDateGreaterThanEqualOrderByEventDateAsc(
                        groupId,
                        Instant.EPOCH
                )) {
            attendance.deleteByEventId(event.getId());
        }
        chatMessages.deleteByGroupId(groupId);
        events.deleteByGroupId(groupId);
        joinRequests.deleteByGroupId(groupId);
        members.deleteByGroupId(groupId);
        groups.delete(group);
    }

    @Transactional(readOnly = true)
    public CommunityGroupResponse resolveInvite(AppUser user, String inviteCode) {
        ageGate.requireAdult(user);
        CommunityGroup group = groups.findByInviteCode(inviteCode)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Davet bağlantısı geçersiz"
                ));
        return response(group, user);
    }

    private CommunityGroupResponse response(CommunityGroup group, AppUser user) {
        String role = members.findByGroupIdAndUserId(group.getId(), user.getId())
                .map(member -> effectiveRole(member, group).name())
                .orElse(null);
        String requestStatus = joinRequests
                .findByGroupIdAndRequesterId(group.getId(), user.getId())
                .map(request -> request.getStatus().name())
                .orElse(null);
        String pinnedMessageText = group.getPinnedMessageId() == null
                ? null
                : chatMessages.findByIdAndGroupId(
                        group.getPinnedMessageId(),
                        group.getId()
                ).map(ChatMessage::getMessage).orElse(null);
        return CommunityGroupResponse.from(
                group,
                members.countByGroupId(group.getId()),
                role,
                requestStatus,
                pinnedMessageText
        );
    }

    private void publishSystem(
            CommunityGroup group,
            AppUser actor,
            String text
    ) {
        ChatMessage message = new ChatMessage();
        message.setGroup(group);
        message.setSender(actor);
        message.setMessage(text);
        message.setMessageType(ChatMessageType.SYSTEM_ACTIVITY);
        ChatMessageResponse response =
                ChatMessageResponse.from(chatMessages.save(message));
        if (realtimePublisher != null) {
            realtimePublisher.publishAfterCommit(response);
        }
    }

    private GroupEventResponse eventResponse(GroupEvent event, AppUser user) {
        String currentAttendance = attendance
                .findByEventIdAndUserId(event.getId(), user.getId())
                .map(answer -> answer.getStatus().name())
                .orElse(null);
        List<GroupEventAttendeeResponse> attendeeList = attendeeResponses(event.getId());
        return GroupEventResponse.from(
                event,
                attendeeList.size(),
                currentAttendance,
                attendeeList
        );
    }

    private List<GroupEventAttendeeResponse> attendeeResponses(Long eventId) {
        return attendance.findByEventIdAndStatusOrderByRespondedAtAsc(
                        eventId,
                        AttendanceStatus.ATTENDING
                ).stream()
                .map(GroupEventAttendeeResponse::from)
                .toList();
    }

    private CommunityGroup findGroup(Long groupId) {
        return groups.findById(groupId)
                .orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı"));
    }

    private GroupEvent findEvent(Long groupId, Long eventId) {
        return events.findByIdAndGroupId(eventId, groupId)
                .orElseThrow(() -> new IllegalArgumentException("Etkinlik bulunamadı"));
    }

    private GroupMember findMember(Long groupId, Long userId) {
        return members.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi bulunamadı"));
    }

    private void requireMember(AppUser user, Long groupId) {
        requireMemberRecord(user, groupId);
    }

    private GroupMember requireMemberRecord(AppUser user, Long groupId) {
        ageGate.requireAdult(user);
        return members.findByGroupIdAndUserId(groupId, user.getId())
                .orElseThrow(() -> new AccessDeniedException("Grup üyesi değilsiniz"));
    }

    private void requireAdmin(AppUser user, Long groupId) {
        CommunityGroup group = findGroup(groupId);
        GroupMember member = requireMemberRecord(user, groupId);
        if (!isFounder(member, group) && !isAdmin(member.getRole())) {
            throw new AccessDeniedException(
                    "Bu işlem için grup yöneticisi olmalısınız"
            );
        }
    }

    private void requireFounder(AppUser user, Long groupId) {
        CommunityGroup group = findGroup(groupId);
        GroupMember member = requireMemberRecord(user, groupId);
        if (!isFounder(member, group)) {
            throw new AccessDeniedException(
                    "Bu işlemi yalnızca grup kurucusu yapabilir"
            );
        }
    }

    private GroupMemberResponse memberResponse(
            GroupMember member,
            CommunityGroup group
    ) {
        return GroupMemberResponse.from(member, effectiveRole(member, group).name());
    }

    private GroupRole effectiveRole(GroupMember member, CommunityGroup group) {
        if (isFounder(member, group)) {
            return GroupRole.FOUNDER;
        }
        return isAdmin(member.getRole()) ? GroupRole.ADMIN : GroupRole.MEMBER;
    }

    private boolean isFounder(GroupMember member, CommunityGroup group) {
        return group.getCreator().getId().equals(member.getUser().getId());
    }

    private boolean isAdmin(GroupRole role) {
        return role == GroupRole.ADMIN || role == GroupRole.GROUP_ADMIN;
    }

    private String normalized(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT);
    }

    private String required(String value, String field, int maxLength) {
        String clean = sanitizer.plainText(value, field, maxLength);
        if (clean == null || clean.isBlank()) {
            throw new IllegalArgumentException(field + " zorunludur");
        }
        return clean;
    }
}
