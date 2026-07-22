package com.ecovision.backend.service;

import com.ecovision.backend.dto.EventRequest;
import com.ecovision.backend.dto.EventResponse;
import com.ecovision.backend.dto.EventMemberResponse;
import com.ecovision.backend.dto.GroupMissionRequest;
import com.ecovision.backend.dto.GroupMissionResponse;
import com.ecovision.backend.dto.GroupWasteReportRequest;
import com.ecovision.backend.dto.GroupWasteReportResponse;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.model.EventMember;
import com.ecovision.backend.model.GroupMission;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.model.GroupWasteReport;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.GroupMissionRepository;
import com.ecovision.backend.repository.GroupWasteReportRepository;
import com.ecovision.backend.repository.GroupInviteRepository;
import com.ecovision.backend.repository.SocialReportRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EventService {
    private final EventRepository eventRepository;
    private final EventMemberRepository eventMemberRepository;
    private final GroupMissionRepository groupMissionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final GroupWasteReportRepository groupWasteReportRepository;
    private final PasswordEncoder passwordEncoder;
    private final AgeGateService ageGateService;
    private final GroupInviteRepository groupInviteRepository;
    private final SocialReportRepository socialReportRepository;
    private final NotificationService notificationService;

    public EventService(
            EventRepository eventRepository,
            EventMemberRepository eventMemberRepository,
            GroupMissionRepository groupMissionRepository,
            ChatMessageRepository chatMessageRepository,
            GroupWasteReportRepository groupWasteReportRepository,
            PasswordEncoder passwordEncoder,
            AgeGateService ageGateService,
            GroupInviteRepository groupInviteRepository,
            SocialReportRepository socialReportRepository,
            NotificationService notificationService
    ) {
        this.eventRepository = eventRepository;
        this.eventMemberRepository = eventMemberRepository;
        this.groupMissionRepository = groupMissionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.groupWasteReportRepository = groupWasteReportRepository;
        this.passwordEncoder = passwordEncoder;
        this.ageGateService = ageGateService;
        this.groupInviteRepository = groupInviteRepository;
        this.socialReportRepository = socialReportRepository;
        this.notificationService = notificationService;
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getEvents(AppUser currentUser, String query) {
        ageGateService.requireAdult(currentUser);
        String city = currentUser.getCity() == null ? AppUser.DEFAULT_CITY : currentUser.getCity();
        return eventRepository.findByCityIgnoreCaseAndTitleContainingIgnoreCaseOrderByEventDateAsc(
                        city, query == null ? "" : query.trim())
                .stream()
                .map(event -> response(event, currentUser))
                .toList();
    }

    @Transactional
    public EventResponse createEvent(AppUser creator, EventRequest request) {
        ageGateService.requireAdult(creator);
        Event event = toEvent(creator, request);
        eventRepository.save(event);
        addMember(event, creator, GroupRole.ADMIN);
        notificationService.notifyCityEvent(event);
        return response(event, creator);
    }

    @Transactional
    public EventResponse joinEvent(AppUser user, Long eventId, JoinEventRequest request) {
        ageGateService.requireAdult(user);
        Event event = findEvent(eventId);
        if (eventMemberRepository.existsByEventIdAndUserId(eventId, user.getId())) {
            return response(event, user);
        }
        if (eventMemberRepository.countByEventId(eventId) >= event.getMemberLimit()) {
            throw new IllegalArgumentException("Grup üye sınırına ulaştı");
        }
        if (event.isPrivateGroup()) {
            String code = request == null ? null : request.joinCode();
            if (code == null || !passwordEncoder.matches(code, event.getJoinCodeHash())) {
                throw new IllegalArgumentException("Grup katılım parolası hatalı");
            }
        }
        addMember(event, user, GroupRole.MEMBER);
        return response(event, user);
    }

    @Transactional(readOnly = true)
    public List<EventMemberResponse> getMembers(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        requireMember(user, eventId);
        return eventMemberRepository.findByEventIdOrderByJoinedAtAsc(eventId)
                .stream().map(EventMemberResponse::from).toList();
    }

    @Transactional
    public EventMemberResponse promoteToAdmin(AppUser user, Long eventId, Long memberUserId) {
        ageGateService.requireAdult(user);
        Event event = findEvent(eventId);
        requireAdmin(user, event);
        EventMember member = eventMemberRepository.findByEventIdAndUserId(eventId, memberUserId)
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi bulunamadı"));
        member.setRole(GroupRole.ADMIN);
        return EventMemberResponse.from(eventMemberRepository.save(member));
    }

    @Transactional(readOnly = true)
    public List<GroupWasteReportResponse> getWasteReports(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        requireMember(user, eventId);
        return groupWasteReportRepository.findByEventIdOrderByReportedAtDesc(eventId)
                .stream().map(GroupWasteReportResponse::from).toList();
    }

    @Transactional
    public GroupWasteReportResponse createWasteReport(
            AppUser user,
            Long eventId,
            GroupWasteReportRequest request
    ) {
        Event event = findEvent(eventId);
        requireMember(user, eventId);
        GroupWasteReport report = new GroupWasteReport();
        report.setEvent(event);
        report.setReporter(user);
        report.setMaterialType(request.materialType().trim());
        report.setItemCount(request.itemCount());
        return GroupWasteReportResponse.from(groupWasteReportRepository.save(report));
    }

    @Transactional(readOnly = true)
    public List<GroupMissionResponse> getMissions(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        findEvent(eventId);
        requireMember(user, eventId);
        return groupMissionRepository.findByEventIdOrderByCreatedAtDesc(eventId)
                .stream()
                .map(GroupMissionResponse::from)
                .toList();
    }

    @Transactional
    public GroupMissionResponse createMission(
            AppUser user,
            Long eventId,
            GroupMissionRequest request
    ) {
        Event event = findEvent(eventId);
        requireAdmin(user, event);

        GroupMission mission = new GroupMission();
        mission.setEvent(event);
        mission.setTitle(request.title().trim());
        mission.setTargetAmount(request.targetAmount());
        mission.setUnit(request.unit().trim());
        return GroupMissionResponse.from(groupMissionRepository.save(mission));
    }

    @Transactional
    public void deleteEvent(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        Event event = findEvent(eventId);
        requireAdmin(user, event);
        deleteEventData(event);
    }

    @Transactional
    public void deleteEventAsSuperuser(Long eventId) {
        deleteEventData(findEvent(eventId));
    }

    private void deleteEventData(Event event) {
        Long eventId = event.getId();
        chatMessageRepository.deleteByEventId(eventId);
        groupWasteReportRepository.deleteByEventId(eventId);
        groupMissionRepository.deleteByEventId(eventId);
        groupInviteRepository.deleteByEventId(eventId);
        socialReportRepository.deleteByReportedEventId(eventId);
        eventMemberRepository.deleteByEventId(eventId);
        eventRepository.delete(event);
    }

    private Event toEvent(AppUser creator, EventRequest request) {
        Event event = new Event();
        event.setCreator(creator);
        event.setTitle(request.title());
        event.setDescription(request.description());
        event.setCity(request.city().trim());
        event.setDistrict(request.district().trim());
        event.setNeighborhood(request.neighborhood().trim());
        event.setLocation(request.city().trim() + ", " + request.district().trim() + " - " + request.neighborhood().trim());
        event.setEventDate(request.eventDate());
        configureGroup(
                event,
                request.memberLimit(),
                request.joinCode()
        );
        return event;
    }

    private Event findEvent(Long eventId) {
        return eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Temizlik grubu bulunamadı"));
    }

    private void requireAdmin(AppUser user, Event event) {
        ageGateService.requireAdult(user);
        boolean admin = eventMemberRepository.findByEventIdAndUserId(event.getId(), user.getId())
                .map(member -> member.getRole() == GroupRole.ADMIN)
                .orElse(event.getCreator().getId().equals(user.getId()));
        if (!admin) {
            throw new IllegalArgumentException("Bu işlem yalnızca grup yöneticilerine açıktır");
        }
    }

    private void requireMember(AppUser user, Long eventId) {
        ageGateService.requireAdult(user);
        if (!eventMemberRepository.existsByEventIdAndUserId(eventId, user.getId())) {
            throw new IllegalArgumentException("Önce gruba katılmalısınız");
        }
    }

    private EventResponse response(Event event, AppUser user) {
        String role = eventMemberRepository.findByEventIdAndUserId(event.getId(), user.getId())
                .map(member -> member.getRole().name())
                .orElse(null);
        return EventResponse.from(event, eventMemberRepository.countByEventId(event.getId()), role);
    }

    private void configureGroup(
            Event event,
            Integer memberLimit,
            String joinCode
    ) {
        event.setMemberLimit(memberLimit == null ? 20 : memberLimit);
        event.setJoinCodeHash(
                joinCode == null || joinCode.isBlank()
                        ? null
                        : passwordEncoder.encode(joinCode.trim())
        );
    }

    private void addMember(Event event, AppUser user, GroupRole role) {
        EventMember member = new EventMember();
        member.setEvent(event);
        member.setUser(user);
        member.setRole(role);
        eventMemberRepository.save(member);
    }
}
