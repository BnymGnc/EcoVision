package com.ecovision.backend.controller;

import com.ecovision.backend.dto.AddGroupMemberRequest;
import com.ecovision.backend.dto.CommunityGroupRequest;
import com.ecovision.backend.dto.CommunityGroupResponse;
import com.ecovision.backend.dto.EventRsvpRequest;
import com.ecovision.backend.dto.GroupEventAttendeeResponse;
import com.ecovision.backend.dto.GroupEventRequest;
import com.ecovision.backend.dto.GroupEventResponse;
import com.ecovision.backend.dto.GroupMemberResponse;
import com.ecovision.backend.dto.GroupJoinRequestResponse;
import com.ecovision.backend.dto.JoinEventRequest;
import com.ecovision.backend.dto.PinGroupContentRequest;
import com.ecovision.backend.dto.UpdateCommunityGroupRequest;
import com.ecovision.backend.service.CommunityGroupService;
import com.ecovision.backend.service.CurrentUserService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/groups")
public class CommunityGroupController {
    private final CommunityGroupService groups;
    private final CurrentUserService current;

    public CommunityGroupController(
            CommunityGroupService groups,
            CurrentUserService current
    ) {
        this.groups = groups;
        this.current = current;
    }

    @GetMapping
    public List<CommunityGroupResponse> list(
            @RequestParam(defaultValue = "") String query,
            @RequestParam(defaultValue = "") String cities,
            @RequestParam(defaultValue = "") String district
    ) {
        return groups.list(current.currentUser(), query, cities, district);
    }

    @GetMapping("/{groupId}")
    public CommunityGroupResponse get(@PathVariable Long groupId) {
        return groups.get(current.currentUser(), groupId);
    }

    @GetMapping("/invite/{inviteCode}")
    public CommunityGroupResponse resolveInvite(@PathVariable String inviteCode) {
        return groups.resolveInvite(current.currentUser(), inviteCode);
    }

    @PostMapping("/invite/{inviteCode}/join")
    public CommunityGroupResponse joinByInvite(@PathVariable String inviteCode) {
        return groups.joinByInvite(current.currentUser(), inviteCode);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public CommunityGroupResponse create(
            @Valid @RequestBody CommunityGroupRequest request
    ) {
        return groups.create(current.currentUser(), request, null);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommunityGroupResponse createWithCover(
            @Valid @RequestPart("group") CommunityGroupRequest request,
            @RequestPart(value = "coverImage", required = false) MultipartFile cover
    ) {
        return groups.create(current.currentUser(), request, cover);
    }

    @PostMapping("/{groupId}/join")
    public CommunityGroupResponse join(
            @PathVariable Long groupId,
            @RequestBody(required = false) JoinEventRequest request
    ) {
        return groups.join(current.currentUser(), groupId, request);
    }

    @PostMapping("/{groupId}/join-requests")
    public GroupJoinRequestResponse requestToJoin(@PathVariable Long groupId) {
        return groups.requestToJoin(current.currentUser(), groupId);
    }

    @GetMapping("/{groupId}/join-requests")
    public List<GroupJoinRequestResponse> pendingRequests(
            @PathVariable Long groupId
    ) {
        return groups.pendingRequests(current.currentUser(), groupId);
    }

    @PostMapping("/{groupId}/join-requests/{requestId}/approve")
    public GroupJoinRequestResponse approveRequest(
            @PathVariable Long groupId,
            @PathVariable Long requestId
    ) {
        return groups.reviewJoinRequest(
                current.currentUser(),
                groupId,
                requestId,
                true
        );
    }

    @PostMapping("/{groupId}/join-requests/{requestId}/reject")
    public GroupJoinRequestResponse rejectRequest(
            @PathVariable Long groupId,
            @PathVariable Long requestId
    ) {
        return groups.reviewJoinRequest(
                current.currentUser(),
                groupId,
                requestId,
                false
        );
    }

    @PutMapping(
            value = "/{groupId}",
            consumes = MediaType.APPLICATION_JSON_VALUE
    )
    public CommunityGroupResponse update(
            @PathVariable Long groupId,
            @Valid @RequestBody UpdateCommunityGroupRequest request
    ) {
        return groups.update(current.currentUser(), groupId, request, null);
    }

    @PutMapping(
            value = "/{groupId}",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public CommunityGroupResponse updateWithCover(
            @PathVariable Long groupId,
            @Valid @RequestPart("group") UpdateCommunityGroupRequest request,
            @RequestPart(value = "coverImage", required = false) MultipartFile cover
    ) {
        return groups.update(current.currentUser(), groupId, request, cover);
    }

    @GetMapping("/{groupId}/members")
    public List<GroupMemberResponse> members(@PathVariable Long groupId) {
        return groups.members(current.currentUser(), groupId);
    }

    @PostMapping("/{groupId}/members")
    public GroupMemberResponse addMember(
            @PathVariable Long groupId,
            @Valid @RequestBody AddGroupMemberRequest request
    ) {
        return groups.addMember(current.currentUser(), groupId, request);
    }

    @PostMapping("/{groupId}/members/{userId}/admin")
    public GroupMemberResponse promote(
            @PathVariable Long groupId,
            @PathVariable Long userId
    ) {
        return groups.promote(current.currentUser(), groupId, userId);
    }

    @DeleteMapping("/{groupId}/members/{userId}/admin")
    public GroupMemberResponse demote(
            @PathVariable Long groupId,
            @PathVariable Long userId
    ) {
        return groups.demote(current.currentUser(), groupId, userId);
    }

    @DeleteMapping("/{groupId}/members/{userId}")
    public ResponseEntity<Void> removeMember(
            @PathVariable Long groupId,
            @PathVariable Long userId
    ) {
        groups.removeMember(current.currentUser(), groupId, userId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{groupId}/membership")
    public ResponseEntity<Void> leaveGroup(@PathVariable Long groupId) {
        groups.leaveGroup(current.currentUser(), groupId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{groupId}/events")
    public List<GroupEventResponse> events(@PathVariable Long groupId) {
        return groups.groupEvents(current.currentUser(), groupId);
    }

    @PostMapping(
            value = "/{groupId}/events",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public GroupEventResponse createEvent(
            @PathVariable Long groupId,
            @Valid @RequestPart("event") GroupEventRequest request,
            @RequestPart(value = "coverImage", required = false) MultipartFile cover
    ) {
        return groups.createEvent(current.currentUser(), groupId, request, cover);
    }

    @PostMapping(
            value = "/{groupId}/events",
            consumes = MediaType.APPLICATION_JSON_VALUE
    )
    public GroupEventResponse createEventWithoutCover(
            @PathVariable Long groupId,
            @Valid @RequestBody GroupEventRequest request
    ) {
        return groups.createEvent(current.currentUser(), groupId, request, null);
    }

    @PostMapping("/{groupId}/events/{eventId}/rsvp")
    public GroupEventResponse rsvp(
            @PathVariable Long groupId,
            @PathVariable Long eventId,
            @Valid @RequestBody EventRsvpRequest request
    ) {
        return groups.rsvp(current.currentUser(), groupId, eventId, request);
    }

    @DeleteMapping("/{groupId}/events/{eventId}/rsvp")
    public GroupEventResponse leaveEvent(
            @PathVariable Long groupId,
            @PathVariable Long eventId
    ) {
        return groups.leaveEvent(current.currentUser(), groupId, eventId);
    }

    @GetMapping("/{groupId}/events/{eventId}/attendees")
    public List<GroupEventAttendeeResponse> attendees(
            @PathVariable Long groupId,
            @PathVariable Long eventId
    ) {
        return groups.attendees(current.currentUser(), groupId, eventId);
    }

    @PutMapping("/{groupId}/pin")
    public CommunityGroupResponse pinContent(
            @PathVariable Long groupId,
            @Valid @RequestBody PinGroupContentRequest request
    ) {
        return groups.pinContent(current.currentUser(), groupId, request);
    }

    @DeleteMapping("/{groupId}/events/{eventId}")
    public ResponseEntity<Void> deleteEvent(
            @PathVariable Long groupId,
            @PathVariable Long eventId
    ) {
        groups.deleteEvent(current.currentUser(), groupId, eventId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{groupId}")
    public ResponseEntity<Void> deleteGroup(@PathVariable Long groupId) {
        groups.deleteGroup(current.currentUser(), groupId);
        return ResponseEntity.noContent().build();
    }
}
