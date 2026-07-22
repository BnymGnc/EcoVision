package com.ecovision.backend.controller;

import com.ecovision.backend.dto.*;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.SocialService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/social")
public class SocialController {
    private final SocialService social; private final CurrentUserService current;
    public SocialController(SocialService social, CurrentUserService current) { this.social = social; this.current = current; }
    @GetMapping("/users/{id}") public PublicProfileResponse profile(@PathVariable Long id) { return social.profile(current.currentUser(), id); }
    @PostMapping("/users/{id}/like") public SocialActionResponse like(@PathVariable Long id) { return social.like(current.currentUser(), id); }
    @DeleteMapping("/users/{id}/like") public SocialActionResponse unlike(@PathVariable Long id) { return social.unlike(current.currentUser(), id); }
    @PostMapping("/friends/{id}/request") public FriendRequestResponse friend(@PathVariable Long id) { return social.requestFriend(current.currentUser(), id); }
    @PostMapping("/friends/requests/{id}/accept") public FriendRequestResponse accept(@PathVariable Long id) { return social.acceptFriend(current.currentUser(), id); }
    @GetMapping("/friends") public List<SocialUserResponse> friends() { return social.friends(current.currentUser()); }
    @GetMapping("/friends/requests") public List<FriendRequestResponse> requests() { return social.incomingRequests(current.currentUser()); }
    @PostMapping("/groups/{eventId}/invites/{friendId}") public GroupInviteResponse invite(@PathVariable Long eventId, @PathVariable Long friendId) { return social.inviteFriend(current.currentUser(), eventId, friendId); }
    @GetMapping("/group-invites") public List<GroupInviteResponse> invites() { return social.groupInvites(current.currentUser()); }
    @PostMapping("/group-invites/{id}/accept") public GroupInviteResponse acceptInvite(@PathVariable Long id) { return social.acceptInvite(current.currentUser(), id); }
    @PostMapping("/reports/users/{id}") public SocialActionResponse reportUser(@PathVariable Long id, @Valid @RequestBody ReportRequest body) { return social.reportUser(current.currentUser(), id, body); }
    @PostMapping("/reports/groups/{id}") public SocialActionResponse reportGroup(@PathVariable Long id, @Valid @RequestBody ReportRequest body) { return social.reportGroup(current.currentUser(), id, body); }
    @PostMapping("/blocks/{id}") public SocialActionResponse block(@PathVariable Long id) { return social.block(current.currentUser(), id); }
    @DeleteMapping("/blocks/{id}") public SocialActionResponse unblock(@PathVariable Long id) { return social.unblock(current.currentUser(), id); }
}
