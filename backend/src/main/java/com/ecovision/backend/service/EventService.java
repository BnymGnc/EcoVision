package com.ecovision.backend.service;

import com.ecovision.backend.dto.EventRequest;
import com.ecovision.backend.dto.EventResponse;
import com.ecovision.backend.model.AppUser;
import com.ecovision.backend.model.Event;
import com.ecovision.backend.repository.EventRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class EventService {
    private final EventRepository eventRepository;
    private final FileStorageService fileStorageService;

    public EventService(EventRepository eventRepository, FileStorageService fileStorageService) {
        this.eventRepository = eventRepository;
        this.fileStorageService = fileStorageService;
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getEvents() {
        return eventRepository.findAllByOrderByEventDateAsc()
                .stream()
                .map(EventResponse::from)
                .toList();
    }

    @Transactional
    public EventResponse createEvent(AppUser creator, EventRequest request) {
        Event event = toEvent(creator, request);
        return EventResponse.from(eventRepository.save(event));
    }

    @Transactional
    public EventResponse createEventMultipart(
            AppUser creator,
            String title,
            String description,
            String location,
            Instant eventDate,
            MultipartFile image
    ) {
        Event event = new Event();
        event.setCreator(creator);
        event.setTitle(title);
        event.setDescription(description);
        event.setLocation(location);
        event.setEventDate(eventDate);
        event.setImageUrl(fileStorageService.store(image, "events"));
        return EventResponse.from(eventRepository.save(event));
    }

    private Event toEvent(AppUser creator, EventRequest request) {
        Event event = new Event();
        event.setCreator(creator);
        event.setTitle(request.title());
        event.setDescription(request.description());
        event.setLocation(request.location());
        event.setEventDate(request.eventDate());
        event.setImageUrl(request.imageUrl());
        return event;
    }
}
