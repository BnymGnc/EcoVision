package com.ecovision.backend.service;

import com.ecovision.backend.dto.EventRequest;
import com.ecovision.backend.dto.EventResponse;
import com.ecovision.backend.dto.EventMemberResponse;
import com.ecovision.backend.dto.EventAttendeeResponse;
import com.ecovision.backend.dto.EventRsvpRequest;
import com.ecovision.backend.dto.GroupMissionRequest;
import com.ecovision.backend.dto.GroupMissionResponse;
import com.ecovision.backend.dto.GroupWasteReportRequest;
import com.ecovision.backend.dto.GroupWasteReportResponse;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.AttendanceStatus;
import com.ecovision.backend.model.ChatMessage;
import com.ecovision.backend.model.ChatMessageType;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.model.EventAttendance;
import com.ecovision.backend.model.EventMember;
import com.ecovision.backend.model.GroupMission;
import com.ecovision.backend.model.GroupRole;
import com.ecovision.backend.model.GroupWasteReport;
import com.ecovision.backend.model.QuestTriggerType;
import com.ecovision.backend.repository.ChatMessageRepository;
import com.ecovision.backend.repository.EventMemberRepository;
import com.ecovision.backend.repository.EventAttendanceRepository;
import com.ecovision.backend.repository.EventRepository;
import com.ecovision.backend.repository.GroupMissionRepository;
import com.ecovision.backend.repository.GroupWasteReportRepository;
import com.ecovision.backend.repository.GroupInviteRepository;
import com.ecovision.backend.repository.SocialReportRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

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
    private final EventAttendanceRepository attendanceRepository;
    private final FileStorageService fileStorageService;
    private final InputSanitizer inputSanitizer;
    private final QuestEventPublisher questEvents;

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
            NotificationService notificationService,
            EventAttendanceRepository attendanceRepository,
            FileStorageService fileStorageService,
            InputSanitizer inputSanitizer,
            QuestEventPublisher questEvents
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
        this.attendanceRepository = attendanceRepository;
        this.fileStorageService = fileStorageService;
        this.inputSanitizer = inputSanitizer;
        this.questEvents = questEvents;
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getEvents(
            AppUser currentUser,
            String query,
            String city,
            String district,
            String cities
    ) {
        ageGateService.requireAdult(currentUser);
        java.util.Set<String> selectedCities = java.util.Arrays.stream(
                        cities == null ? new String[0] : cities.split(",")
                )
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .collect(java.util.stream.Collectors.toUnmodifiableSet());
        String selectedCity = city == null ? "" : city.trim();
        if (selectedCities.isEmpty() && !selectedCity.isBlank()) {
            selectedCities = java.util.Set.of(selectedCity);
        }
        String selectedDistrict = district == null ? "" : district.trim();
        String search = query == null ? "" : query.trim();
        java.util.Set<String> cityFilter = selectedCities;
        return eventRepository.findAllByOrderByEventDateAsc()
                .stream()
                .filter(event -> cityFilter.isEmpty()
                        || cityFilter.stream().anyMatch(
                        selected -> selected.equalsIgnoreCase(event.getCity())
                ))
                .filter(event -> selectedDistrict.isBlank()
                        || selectedDistrict.equalsIgnoreCase(event.getDistrict()))
                .filter(event -> search.isBlank()
                        || event.getTitle().toLowerCase(java.util.Locale.ROOT)
                        .contains(search.toLowerCase(java.util.Locale.ROOT)))
                .map(event -> response(event, currentUser))
                .toList();
    }

    @Transactional
    public EventResponse createEvent(AppUser creator, EventRequest request) {
        return createEvent(creator, request, null);
    }

    @Transactional
    public EventResponse createEvent(
            AppUser creator,
            EventRequest request,
            MultipartFile coverImage
    ) {
        ageGateService.requireAdult(creator);
        Event event = toEvent(creator, request);
        event.setCoverImageUrl(fileStorageService.storeImage(coverImage, "events"));
        eventRepository.save(event);
        addMember(event, creator, GroupRole.GROUP_ADMIN);
        addEventCard(event, creator);
        notificationService.notifyCityEvent(event);
        questEvents.publish(
                creator.getId(),
                QuestTriggerType.INVITE_FRIEND,
                1,
                Map.of("action", "event_created", "eventId", event.getId())
        );
        return response(event, creator);
    }

    @Transactional
    public EventResponse updateEvent(
            AppUser user,
            Long eventId,
            EventRequest request,
            MultipartFile coverImage
    ) {
        Event event = findEvent(eventId);
        requireAdmin(user, event);
        event.setTitle(inputSanitizer.plainText(request.title(), "Başlık", 150));
        event.setDescription(inputSanitizer.plainText(
                request.description(),
                "Açıklama",
                2000
        ));
        event.setCity(inputSanitizer.plainText(request.city(), "İl", 60));
        event.setDistrict(inputSanitizer.plainText(request.district(), "İlçe", 60));
        event.setNeighborhood(inputSanitizer.plainText(
                request.neighborhood(),
                "Mahalle",
                100
        ));
        event.setExactAddress(inputSanitizer.plainText(
                request.exactAddress(),
                "Açık adres",
                500
        ));
        event.setLocation(event.getCity() + ", " + event.getDistrict()
                + " - " + event.getNeighborhood());
        event.setEventDate(request.eventDate());
        event.setEventTime(request.eventTime());
        configureGroup(event, request.memberLimit(), request.joinCode());
        if (coverImage != null && !coverImage.isEmpty()) {
            event.setCoverImageUrl(fileStorageService.storeImage(coverImage, "events"));
        }
        return response(eventRepository.save(event), user);
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
        member.setRole(GroupRole.GROUP_ADMIN);
        return EventMemberResponse.from(eventMemberRepository.save(member));
    }

    @Transactional
    public void removeMember(AppUser user, Long eventId, Long memberUserId) {
        Event event = findEvent(eventId);
        requireAdmin(user, event);
        if (event.getCreator().getId().equals(memberUserId)) {
            throw new IllegalArgumentException("Grup kurucusu gruptan çıkarılamaz");
        }
        EventMember member = eventMemberRepository.findByEventIdAndUserId(eventId, memberUserId)
                .orElseThrow(() -> new IllegalArgumentException("Grup üyesi bulunamadı"));
        attendanceRepository.deleteByEventIdAndUserId(eventId, memberUserId);
        eventMemberRepository.delete(member);
    }

    @Transactional
    public EventResponse updateAttendance(
            AppUser user,
            Long eventId,
            EventRsvpRequest request
    ) {
        Event event = findEvent(eventId);
        requireMember(user, eventId);
        EventAttendance attendance = attendanceRepository
                .findByEventIdAndUserId(eventId, user.getId())
                .orElseGet(EventAttendance::new);
        boolean newlyAttending = request.status() == AttendanceStatus.ATTENDING
                && attendance.getStatus() != AttendanceStatus.ATTENDING;
        attendance.setEvent(event);
        attendance.setUser(user);
        attendance.setStatus(request.status());
        attendanceRepository.save(attendance);
        if (newlyAttending) {
            questEvents.publish(
                    user.getId(),
                    QuestTriggerType.INVITE_FRIEND,
                    1,
                    Map.of("action", "event_attended", "eventId", eventId)
            );
        }
        return response(event, user);
    }

    @Transactional(readOnly = true)
    public List<EventAttendeeResponse> getAttendees(AppUser user, Long eventId) {
        requireMember(user, eventId);
        return attendanceRepository
                .findByEventIdAndStatusOrderByRespondedAtAsc(
                        eventId,
                        AttendanceStatus.ATTENDING
                )
                .stream()
                .map(EventAttendeeResponse::from)
                .toList();
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
        if (!event.getCreator().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Yalnızca etkinlik kurucusu etkinliği silebilir");
        }
        deleteEventData(event);
    }

    @Transactional
    public void deleteEventAsSuperuser(Long eventId) {
        deleteEventData(findEvent(eventId));
    }

    private void deleteEventData(Event event) {
        Long eventId = event.getId();
        chatMessageRepository.deleteByEventId(eventId);
        attendanceRepository.deleteByEventId(eventId);
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
        event.setTitle(inputSanitizer.plainText(request.title(), "Başlık", 150));
        event.setDescription(inputSanitizer.plainText(request.description(), "Açıklama", 2000));
        event.setCity(inputSanitizer.plainText(request.city(), "İl", 60));
        event.setDistrict(inputSanitizer.plainText(request.district(), "İlçe", 60));
        event.setNeighborhood(inputSanitizer.plainText(request.neighborhood(), "Mahalle", 100));
        event.setExactAddress(inputSanitizer.plainText(
                request.exactAddress(),
                "Açık adres",
                500
        ));
        event.setLocation(
                event.getCity() + ", " + event.getDistrict() + " - " + event.getNeighborhood()
        );
        event.setEventDate(request.eventDate());
        event.setEventTime(request.eventTime());
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
                .map(member -> member.getRole() == GroupRole.GROUP_ADMIN)
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
        String attendance = attendanceRepository
                .findByEventIdAndUserId(event.getId(), user.getId())
                .map(item -> item.getStatus().name())
                .orElse(null);
        return EventResponse.from(
                event,
                eventMemberRepository.countByEventId(event.getId()),
                attendanceRepository.countByEventIdAndStatus(
                        event.getId(),
                        AttendanceStatus.ATTENDING
                ),
                role,
                attendance
        );
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

    private void addEventCard(Event event, AppUser creator) {
        ChatMessage message = new ChatMessage();
        message.setEvent(event);
        message.setSender(creator);
        message.setMessage(event.getTitle());
        message.setMessageType(ChatMessageType.SYSTEM_EVENT);
        chatMessageRepository.save(message);
    }
}
