package com.ecovision.backend.controller;

import com.ecovision.backend.dto.EventRequest;
import com.ecovision.backend.dto.EventResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.EventService;
import jakarta.validation.Valid;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.server.ResponseStatusException;
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
    private static final Logger LOGGER = LoggerFactory.getLogger(EventController.class);

    private final EventService eventService;
    private final CurrentUserService currentUserService;

    public EventController(EventService eventService, CurrentUserService currentUserService) {
        this.eventService = eventService;
        this.currentUserService = currentUserService;
    }

    @GetMapping
    public ResponseEntity<List<EventResponse>> events() {
        try {
            return ResponseEntity.ok(eventService.getEvents());
        } catch (RuntimeException exception) {
            LOGGER.error("Could not load cleanup events", exception);
            return ResponseEntity.ok(List.of());
        }
    }

    @PostMapping
    public EventResponse createEvent(@Valid @RequestBody EventRequest request) {
        try {
            return eventService.createEvent(currentUserService.currentUser(), request);
        } catch (RuntimeException exception) {
            LOGGER.error("Could not create cleanup event", exception);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Could not create cleanup event", exception);
        }
    }

    @PostMapping(value = "/multipart", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public EventResponse createEventMultipart(
            @RequestParam String title,
            @RequestParam String description,
            @RequestParam String location,
            @RequestParam String eventDate,
            @RequestPart(value = "image", required = false) MultipartFile image
    ) {
        try {
            return eventService.createEventMultipart(
                    currentUserService.currentUser(),
                    title,
                    description,
                    location,
                    Instant.parse(eventDate),
                    image
            );
        } catch (DateTimeParseException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid event date", exception);
        } catch (RuntimeException exception) {
            LOGGER.error("Could not create multipart cleanup event", exception);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Could not create cleanup event", exception);
        }
    }
}
