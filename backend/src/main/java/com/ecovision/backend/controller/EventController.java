package com.ecovision.backend.controller;

import com.ecovision.backend.dto.*;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.EventService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/events")
public class EventController {
    private final EventService events; private final CurrentUserService current;
    public EventController(EventService events, CurrentUserService current) { this.events = events; this.current = current; }
    @GetMapping
    public List<EventResponse> events(
            @RequestParam(defaultValue = "") String query,
            @RequestParam(defaultValue = "") String city,
            @RequestParam(defaultValue = "") String district,
            @RequestParam(defaultValue = "") String cities
    ) {
        return events.getEvents(current.currentUser(), query, city, district, cities);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public EventResponse create(@Valid @RequestBody EventRequest body) {
        return events.createEvent(current.currentUser(), body);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public EventResponse createWithCover(
            @Valid @RequestPart("event") EventRequest body,
            @RequestPart(value = "coverImage", required = false) MultipartFile coverImage
    ) {
        return events.createEvent(current.currentUser(), body, coverImage);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public EventResponse update(
            @PathVariable Long id,
            @Valid @RequestBody EventRequest body
    ) {
        return events.updateEvent(current.currentUser(), id, body, null);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public EventResponse updateWithCover(
            @PathVariable Long id,
            @Valid @RequestPart("event") EventRequest body,
            @RequestPart(value = "coverImage", required = false)
            MultipartFile coverImage
    ) {
        return events.updateEvent(current.currentUser(), id, body, coverImage);
    }
    @PostMapping("/{id}/join") public EventResponse join(@PathVariable Long id, @RequestBody(required = false) JoinEventRequest body) { return events.joinEvent(current.currentUser(), id, body); }
    @GetMapping("/{id}/members") public List<EventMemberResponse> members(@PathVariable Long id) { return events.getMembers(current.currentUser(), id); }
    @PostMapping("/{id}/members/{userId}/admin") public EventMemberResponse admin(@PathVariable Long id, @PathVariable Long userId) { return events.promoteToAdmin(current.currentUser(), id, userId); }
    @DeleteMapping("/{id}/members/{userId}") public ResponseEntity<Void> removeMember(@PathVariable Long id, @PathVariable Long userId) { events.removeMember(current.currentUser(), id, userId); return ResponseEntity.noContent().build(); }
    @PutMapping("/{id}/rsvp") public EventResponse rsvp(@PathVariable Long id, @Valid @RequestBody EventRsvpRequest body) { return events.updateAttendance(current.currentUser(), id, body); }
    @GetMapping("/{id}/attendees") public List<EventAttendeeResponse> attendees(@PathVariable Long id) { return events.getAttendees(current.currentUser(), id); }
    @GetMapping("/{id}/missions") public List<GroupMissionResponse> missions(@PathVariable Long id) { return events.getMissions(current.currentUser(), id); }
    @PostMapping("/{id}/missions") public GroupMissionResponse mission(@PathVariable Long id, @Valid @RequestBody GroupMissionRequest body) { return events.createMission(current.currentUser(), id, body); }
    @GetMapping("/{id}/waste-reports") public List<GroupWasteReportResponse> reports(@PathVariable Long id) { return events.getWasteReports(current.currentUser(), id); }
    @PostMapping("/{id}/waste-reports") public GroupWasteReportResponse report(@PathVariable Long id, @Valid @RequestBody GroupWasteReportRequest body) { return events.createWasteReport(current.currentUser(), id, body); }
    @DeleteMapping("/{id}") public ResponseEntity<Void> delete(@PathVariable Long id) { events.deleteEvent(current.currentUser(), id); return ResponseEntity.noContent().build(); }
}
