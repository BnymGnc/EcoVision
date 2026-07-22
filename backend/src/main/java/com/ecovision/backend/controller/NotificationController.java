package com.ecovision.backend.controller;

import com.ecovision.backend.dto.NotificationResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.NotificationService;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private final NotificationService notifications; private final CurrentUserService current;
    public NotificationController(NotificationService notifications, CurrentUserService current) { this.notifications = notifications; this.current = current; }
    @GetMapping public List<NotificationResponse> list(@RequestParam(defaultValue = "50") int limit) { return notifications.list(current.currentUser(), limit); }
    @GetMapping("/unread-count") public Map<String, Long> unread() { return Map.of("count", notifications.unreadCount(current.currentUser())); }
    @PostMapping("/read-all") public Map<String, Integer> readAll() { return Map.of("updated", notifications.markAllRead(current.currentUser())); }
}
