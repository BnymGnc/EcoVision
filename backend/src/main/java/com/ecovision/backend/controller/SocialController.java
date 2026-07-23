package com.ecovision.backend.controller;

import com.ecovision.backend.dto.FriendRequestResponse;
import com.ecovision.backend.dto.GroupInviteResponse;
import com.ecovision.backend.dto.PublicProfileResponse;
import com.ecovision.backend.dto.ReportRequest;
import com.ecovision.backend.dto.SocialActionResponse;
import com.ecovision.backend.dto.SocialUserResponse;
import com.ecovision.backend.dto.UserDiscoveryResponse;
import com.ecovision.backend.service.CurrentUserService;
import com.ecovision.backend.service.SocialService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/social")
public class SocialController {
    private final SocialService socialService;
    private final CurrentUserService currentUserService;

    public SocialController(
            SocialService socialService,
            CurrentUserService currentUserService
    ) {
        this.socialService = socialService;
        this.currentUserService = currentUserService;
    }

    @GetMapping("/users/search")
    public UserDiscoveryResponse search(@RequestParam String username) {
        return socialService.searchByExactUsername(
                currentUserService.currentUser(),
                username
        );
    }

    @GetMapping("/users/{id}")
    public PublicProfileResponse profile(@PathVariable Long id) {
        return socialService.profile(currentUserService.currentUser(), id);
    }

    @PostMapping("/users/{id}/like")
    public SocialActionResponse like(@PathVariable Long id) {
        return socialService.like(currentUserService.currentUser(), id);
    }

    @DeleteMapping("/users/{id}/like")
    public SocialActionResponse unlike(@PathVariable Long id) {
        return socialService.unlike(currentUserService.currentUser(), id);
    }

    @PostMapping("/friends/{id}/request")
    public FriendRequestResponse requestFriend(@PathVariable Long id) {
        return socialService.requestFriend(currentUserService.currentUser(), id);
    }

    @PostMapping("/friends/requests/{id}/accept")
    public FriendRequestResponse acceptFriend(@PathVariable Long id) {
        return socialService.acceptFriend(currentUserService.currentUser(), id);
    }

    @PostMapping("/friends/requests/{id}/reject")
    public FriendRequestResponse rejectFriend(@PathVariable Long id) {
        return socialService.rejectFriend(currentUserService.currentUser(), id);
    }

    @DeleteMapping("/friends/{id}")
    public SocialActionResponse removeFriend(@PathVariable Long id) {
        return socialService.removeFriend(currentUserService.currentUser(), id);
    }

    @GetMapping("/friends")
    public List<SocialUserResponse> friends() {
        return socialService.friends(currentUserService.currentUser());
    }

    @GetMapping("/friends/requests")
    public List<FriendRequestResponse> requests() {
        return socialService.incomingRequests(currentUserService.currentUser());
    }

    @PostMapping("/groups/{eventId}/invites/{friendId}")
    public GroupInviteResponse invite(
            @PathVariable Long eventId,
            @PathVariable Long friendId
    ) {
        return socialService.inviteFriend(
                currentUserService.currentUser(),
                eventId,
                friendId
        );
    }

    @GetMapping("/group-invites")
    public List<GroupInviteResponse> invites() {
        return socialService.groupInvites(currentUserService.currentUser());
    }

    @PostMapping("/group-invites/{id}/accept")
    public GroupInviteResponse acceptInvite(@PathVariable Long id) {
        return socialService.acceptInvite(currentUserService.currentUser(), id);
    }

    @PostMapping("/reports/users/{id}")
    public SocialActionResponse reportUser(
            @PathVariable Long id,
            @Valid @RequestBody ReportRequest request
    ) {
        return socialService.reportUser(currentUserService.currentUser(), id, request);
    }

    @PostMapping("/reports/groups/{id}")
    public SocialActionResponse reportGroup(
            @PathVariable Long id,
            @Valid @RequestBody ReportRequest request
    ) {
        return socialService.reportGroup(currentUserService.currentUser(), id, request);
    }

    @PostMapping("/blocks/{id}")
    public SocialActionResponse block(@PathVariable Long id) {
        return socialService.block(currentUserService.currentUser(), id);
    }

    @DeleteMapping("/blocks/{id}")
    public SocialActionResponse unblock(@PathVariable Long id) {
        return socialService.unblock(currentUserService.currentUser(), id);
    }
}
