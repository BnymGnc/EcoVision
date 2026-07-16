package com.ecovision.backend.controller;

import com.ecovision.backend.dto.EventRequest;
import com.ecovision.backend.dto.EventResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.EventService;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/events")
public class EventController {
    private final EventService eventService;
    private final CurrentUserService currentUserService;

    public EventController(EventService eventService, CurrentUserService currentUserService) {
        this.eventService = eventService;
        this.currentUserService = currentUserService;
    }

    @GetMapping
    public List<EventResponse> events() {
        return eventService.getEvents();
    }

    @PostMapping
    public EventResponse createEvent(@Valid @RequestBody EventRequest request) {
        return eventService.createEvent(currentUserService.currentUser(), request);
    }

    @PostMapping(value = "/multipart", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public EventResponse createEventMultipart(
            @RequestParam String title,
            @RequestParam String description,
            @RequestParam String location,
            @RequestParam String eventDate,
            @RequestPart(value = "image", required = false) MultipartFile image
    ) {
        return eventService.createEventMultipart(
                currentUserService.currentUser(),
                title,
                description,
                location,
                Instant.parse(eventDate),
                image
        );
    }
}
