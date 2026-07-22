package com.ecovision.backend.controller;

import com.ecovision.backend.dto.*;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.SuperuserService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/superuser")
@PreAuthorize("hasRole('SUPERUSER')")
public class SuperuserController {
    private final SuperuserService superuser; private final CurrentUserService current;
    public SuperuserController(SuperuserService superuser, CurrentUserService current) { this.superuser = superuser; this.current = current; }
    @GetMapping("/reports") public List<ModerationReportResponse> reports() { return superuser.reports(); }
    @GetMapping("/audit/chat/{groupId}") public List<ChatMessageResponse> auditGroup(@PathVariable Long groupId, @RequestParam(defaultValue="100") int limit, @RequestParam(defaultValue="0") int offset) { return superuser.auditGroup(groupId, limit, offset); }
    @GetMapping("/audit/user/{userId}") public List<ChatMessageResponse> auditUser(@PathVariable Long userId, @RequestParam(defaultValue="100") int limit, @RequestParam(defaultValue="0") int offset) { return superuser.auditUser(userId, limit, offset); }
    @PostMapping("/broadcast") public Map<String,Integer> broadcast(@Valid @RequestBody BroadcastRequest body) { return Map.of("recipients", superuser.broadcast(body)); }
    @PostMapping("/users/{userId}/ban") public UserResponse ban(@PathVariable Long userId) { return superuser.ban(current.currentUser(), userId); }
    @PostMapping("/users/{userId}/unban") public UserResponse unban(@PathVariable Long userId) { return superuser.unban(current.currentUser(), userId); }
    @PostMapping("/users/{userId}/suspend") public UserResponse suspend(@PathVariable Long userId, @Valid @RequestBody SuspendUserRequest body) { return superuser.suspend(current.currentUser(), userId, body.days()); }
    @DeleteMapping("/groups/{groupId}") public ResponseEntity<Void> deleteGroup(@PathVariable Long groupId) { superuser.deleteGroup(groupId); return ResponseEntity.noContent().build(); }
}
