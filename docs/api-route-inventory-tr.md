# EcoVision: kaynak koddan API envanteri

Tarih: 24 Ekim 2026. `python scripts/document_api_routes.py` ile controller kaynaklarından üretilir.
Bu, canlı sunucu testi değildir. Eski/uyumluluk endpoint'leri de dahildir.
Ana açıklamalar ve ekran/buton bağları: [detaylı proje rehberi](ecovision-architecture-and-flows-tr.md).

HTTP handler tanımı: **138**; STOMP uygulama handler tanımı: **4**.
Aynı URL için JSON/multipart handler'ları ayrı sayılır. Actuator/Swagger framework yolları bu sayıda değildir.

## AdminController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/admin/users` | [users](../backend/src/main/java/com/ecovision/backend/controller/AdminController.java#L28) | `List<UserResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/admin/assign-admin` | [assignAdmin](../backend/src/main/java/com/ecovision/backend/controller/AdminController.java#L33) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/admin/map-pins` | [addOfficialMapPin](../backend/src/main/java/com/ecovision/backend/controller/AdminController.java#L38) | `MapPinResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
users()
assignAdmin(@Valid @RequestBody AssignAdminRequest request)
addOfficialMapPin(@Valid @RequestBody MapPinRequest request)
```

## AuthController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `POST /api/auth/register` | [register](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L45) | `AuthResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/login` | [login](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L50) | `AuthResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/google` | [google](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L55) | `AuthResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/refresh` | [refresh](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L60) | `AuthResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/logout` | [logout](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L65) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/forgot-password` | [forgotPassword](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L73) | `ResponseEntity<java.util.Map<String, String>>` | JSON / query / path; aşağıdaki imza |
| `GET /api/auth/me` | [me](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L84) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/auth/me/profile-picture` | [uploadProfilePicture](../backend/src/main/java/com/ecovision/backend/controller/AuthController.java#L89) | `UserResponse` | multipart |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
register(@Valid @RequestBody RegisterRequest request)
login(@Valid @RequestBody LoginRequest request)
google(@Valid @RequestBody GoogleAuthRequest request)
refresh(@Valid @RequestBody RefreshTokenRequest request)
logout(@Valid @RequestBody RefreshTokenRequest request, @org.springframework.web.bind.annotation.RequestHeader(value = "Authorization", required = false) String authorization)
forgotPassword(@Valid @RequestBody ForgotPasswordRequest request)
me()
uploadProfilePicture(@RequestParam("image") MultipartFile image)
```

## CarbonController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `POST /api/carbon/assessments` | [assess](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L12) | `Map<String, Object>` | JSON / query / path; aşağıdaki imza |
| `GET /api/carbon/assessments` | [assessments](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L15) | `List<Map<String, Object>>` | JSON / query / path; aşağıdaki imza |
| `GET /api/carbon/actions` | [actions](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L16) | `List<CarbonService.ActionResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/carbon/actions` | [action](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L17) | `CarbonService.ActionResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/carbon/actions/{id}` | [delete](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L20) | `void` | JSON / query / path; aşağıdaki imza |
| `PUT /api/carbon/actions/{id}` | [updateMass](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L21) | `CarbonService.ActionResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/carbon/summary` | [summary](../backend/src/main/java/com/ecovision/backend/controller/CarbonController.java#L25) | `CarbonService.Summary` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
assess(@RequestBody CarbonMath.Inputs request)
assessments()
actions()
action(@RequestBody CarbonService.ActionRequest request)
delete(@PathVariable Long id)
updateMass(@PathVariable Long id, @RequestBody MassUpdate request)
summary()
```

## ChatController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/chat/events/{eventId}` | [messages](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L36) | `List<ChatMessageResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/chat/unread-count` | [unreadCount](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L50) | `Map<String, Long>` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/read` | [markRead](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L55) | `Map<String, Boolean>` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/events/{eventId}` | [sendMessage](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L61) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/events/{eventId}/media` | [sendImage](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L69) | `ChatMessageResponse` | multipart |
| `POST /api/chat/events/{eventId}/attachments` | [sendAttachment](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L74) | `ChatMessageResponse` | multipart |
| `GET /api/chat/groups/{groupId}` | [groupMessages](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L85) | `List<ChatMessageResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/groups/{groupId}` | [sendGroupMessage](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L99) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/groups/{groupId}/attachments` | [sendGroupAttachment](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L111) | `ChatMessageResponse` | multipart |
| `GET /api/chat/groups/{groupId}/media` | [groupMedia](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L128) | `List<ChatMessageResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/groups/{groupId}/messages/{messageId}/reactions` | [react](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L142) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/chat/groups/{groupId}/messages/{messageId}` | [deleteGroupMessage](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L156) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/groups/{groupId}/polls` | [createPoll](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L168) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/chat/groups/{groupId}/messages/{messageId}/vote` | [vote](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L180) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/chat/groups/{groupId}/polls/{messageId}` | [deletePoll](../backend/src/main/java/com/ecovision/backend/controller/ChatController.java#L194) | `ChatMessageResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
messages(@PathVariable Long eventId, @RequestParam(defaultValue = "30") int limit, @RequestParam(defaultValue = "0") int offset)
unreadCount()
markRead()
sendMessage(@PathVariable Long eventId, @Valid @RequestBody ChatMessageRequest request)
sendImage(@PathVariable Long eventId, @RequestPart("image") MultipartFile image)
sendAttachment(@PathVariable Long eventId, @RequestPart("file") MultipartFile file)
groupMessages(@PathVariable Long groupId, @RequestParam(defaultValue = "30") int limit, @RequestParam(defaultValue = "0") int offset)
sendGroupMessage(@PathVariable Long groupId, @Valid @RequestBody ChatMessageRequest request)
sendGroupAttachment(@PathVariable Long groupId, @RequestPart("file") MultipartFile file, @RequestParam(required = false) Long replyToMessageId)
groupMedia(@PathVariable Long groupId, @RequestParam(defaultValue = "60") int limit, @RequestParam(defaultValue = "0") int offset)
react(@PathVariable Long groupId, @PathVariable Long messageId, @Valid @RequestBody ChatReactionRequest request)
deleteGroupMessage(@PathVariable Long groupId, @PathVariable Long messageId)
createPoll(@PathVariable Long groupId, @Valid @RequestBody CreatePollRequest request)
vote(@PathVariable Long groupId, @PathVariable Long messageId, @Valid @RequestBody PollVoteRequest request)
deletePoll(@PathVariable Long groupId, @PathVariable Long messageId)
```

## CommunityGroupController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/groups` | [list](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L47) | `List<CommunityGroupResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/groups/{groupId}` | [get](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L56) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/groups/invite/{inviteCode}` | [resolveInvite](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L61) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/invite/{inviteCode}/join` | [joinByInvite](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L66) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups` | [create](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L71) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups` | [createWithCover](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L78) | `CommunityGroupResponse` | multipart |
| `POST /api/groups/{groupId}/join` | [join](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L86) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/join-requests` | [requestToJoin](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L94) | `GroupJoinRequestResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/groups/{groupId}/join-requests` | [pendingRequests](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L99) | `List<GroupJoinRequestResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/join-requests/{requestId}/approve` | [approveRequest](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L106) | `GroupJoinRequestResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/join-requests/{requestId}/reject` | [rejectRequest](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L119) | `GroupJoinRequestResponse` | JSON / query / path; aşağıdaki imza |
| `PUT /api/groups/{groupId}` | [update](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L132) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `PUT /api/groups/{groupId}` | [updateWithCover](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L143) | `CommunityGroupResponse` | multipart |
| `GET /api/groups/{groupId}/members` | [members](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L155) | `List<GroupMemberResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/members` | [addMember](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L160) | `GroupMemberResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/members/{userId}/admin` | [promote](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L168) | `GroupMemberResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}/members/{userId}/admin` | [demote](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L176) | `GroupMemberResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}/members/{userId}` | [removeMember](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L184) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}/membership` | [leaveGroup](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L193) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |
| `GET /api/groups/{groupId}/events` | [events](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L199) | `List<GroupEventResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/events` | [createEvent](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L204) | `GroupEventResponse` | multipart |
| `POST /api/groups/{groupId}/events` | [createEventWithoutCover](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L216) | `GroupEventResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/groups/{groupId}/events/{eventId}/rsvp` | [rsvp](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L227) | `GroupEventResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}/events/{eventId}/rsvp` | [leaveEvent](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L236) | `GroupEventResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/groups/{groupId}/events/{eventId}/attendees` | [attendees](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L244) | `List<GroupEventAttendeeResponse>` | JSON / query / path; aşağıdaki imza |
| `PUT /api/groups/{groupId}/pin` | [pinContent](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L252) | `CommunityGroupResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}/events/{eventId}` | [deleteEvent](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L260) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/groups/{groupId}` | [deleteGroup](../backend/src/main/java/com/ecovision/backend/controller/CommunityGroupController.java#L269) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
list(@RequestParam(defaultValue = "") String query, @RequestParam(defaultValue = "") String cities, @RequestParam(defaultValue = "") String district)
get(@PathVariable Long groupId)
resolveInvite(@PathVariable String inviteCode)
joinByInvite(@PathVariable String inviteCode)
create(@Valid @RequestBody CommunityGroupRequest request)
createWithCover(@Valid @RequestPart("group") CommunityGroupRequest request, @RequestPart(value = "coverImage", required = false) MultipartFile cover)
join(@PathVariable Long groupId, @RequestBody(required = false) JoinEventRequest request)
requestToJoin(@PathVariable Long groupId)
pendingRequests(@PathVariable Long groupId)
approveRequest(@PathVariable Long groupId, @PathVariable Long requestId)
rejectRequest(@PathVariable Long groupId, @PathVariable Long requestId)
update(@PathVariable Long groupId, @Valid @RequestBody UpdateCommunityGroupRequest request)
updateWithCover(@PathVariable Long groupId, @Valid @RequestPart("group") UpdateCommunityGroupRequest request, @RequestPart(value = "coverImage", required = false) MultipartFile cover)
members(@PathVariable Long groupId)
addMember(@PathVariable Long groupId, @Valid @RequestBody AddGroupMemberRequest request)
promote(@PathVariable Long groupId, @PathVariable Long userId)
demote(@PathVariable Long groupId, @PathVariable Long userId)
removeMember(@PathVariable Long groupId, @PathVariable Long userId)
leaveGroup(@PathVariable Long groupId)
events(@PathVariable Long groupId)
createEvent(@PathVariable Long groupId, @Valid @RequestPart("event") GroupEventRequest request, @RequestPart(value = "coverImage", required = false) MultipartFile cover)
createEventWithoutCover(@PathVariable Long groupId, @Valid @RequestBody GroupEventRequest request)
rsvp(@PathVariable Long groupId, @PathVariable Long eventId, @Valid @RequestBody EventRsvpRequest request)
leaveEvent(@PathVariable Long groupId, @PathVariable Long eventId)
attendees(@PathVariable Long groupId, @PathVariable Long eventId)
pinContent(@PathVariable Long groupId, @Valid @RequestBody PinGroupContentRequest request)
deleteEvent(@PathVariable Long groupId, @PathVariable Long eventId)
deleteGroup(@PathVariable Long groupId)
```

## EducationController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/education/progress` | [progress](../backend/src/main/java/com/ecovision/backend/controller/EducationController.java#L30) | `List<String>` | JSON / query / path; aşağıdaki imza |
| `POST /api/education/complete/{categoryId}` | [complete](../backend/src/main/java/com/ecovision/backend/controller/EducationController.java#L35) | `EducationCompletionResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/education/quiz/{categoryId}` | [quiz](../backend/src/main/java/com/ecovision/backend/controller/EducationController.java#L42) | `java.util.Map<String,Object>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
progress()
complete(@PathVariable String categoryId, @org.springframework.web.bind.annotation.RequestBody(required = false) com.ecovision.backend.service.EducationQuizCatalog.Submission submission)
quiz(@PathVariable String categoryId)
```

## EventController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/events` | [events](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L18) | `List<EventResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/events` | [create](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L28) | `EventResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/events` | [createWithCover](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L33) | `EventResponse` | multipart |
| `PUT /api/events/{id}` | [update](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L41) | `EventResponse` | JSON / query / path; aşağıdaki imza |
| `PUT /api/events/{id}` | [updateWithCover](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L49) | `EventResponse` | multipart |
| `POST /api/events/{id}/join` | [join](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L58) | `EventResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/events/{id}/members` | [members](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L59) | `List<EventMemberResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/events/{id}/members/{userId}/admin` | [admin](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L60) | `EventMemberResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/events/{id}/members/{userId}` | [removeMember](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L61) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |
| `PUT /api/events/{id}/rsvp` | [rsvp](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L62) | `EventResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/events/{id}/attendees` | [attendees](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L63) | `List<EventAttendeeResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/events/{id}/missions` | [missions](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L64) | `List<GroupMissionResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/events/{id}/missions` | [mission](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L65) | `GroupMissionResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/events/{id}/waste-reports` | [reports](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L66) | `List<GroupWasteReportResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/events/{id}/waste-reports` | [report](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L67) | `GroupWasteReportResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/events/{id}` | [delete](../backend/src/main/java/com/ecovision/backend/controller/EventController.java#L68) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
events(@RequestParam(defaultValue = "") String query, @RequestParam(defaultValue = "") String city, @RequestParam(defaultValue = "") String district, @RequestParam(defaultValue = "") String cities)
create(@Valid @RequestBody EventRequest body)
createWithCover(@Valid @RequestPart("event") EventRequest body, @RequestPart(value = "coverImage", required = false) MultipartFile coverImage)
update(@PathVariable Long id, @Valid @RequestBody EventRequest body)
updateWithCover(@PathVariable Long id, @Valid @RequestPart("event") EventRequest body, @RequestPart(value = "coverImage", required = false) MultipartFile coverImage)
join(@PathVariable Long id, @RequestBody(required = false) JoinEventRequest body)
members(@PathVariable Long id)
admin(@PathVariable Long id, @PathVariable Long userId)
removeMember(@PathVariable Long id, @PathVariable Long userId)
rsvp(@PathVariable Long id, @Valid @RequestBody EventRsvpRequest body)
attendees(@PathVariable Long id)
missions(@PathVariable Long id)
mission(@PathVariable Long id, @Valid @RequestBody GroupMissionRequest body)
reports(@PathVariable Long id)
report(@PathVariable Long id, @Valid @RequestBody GroupWasteReportRequest body)
delete(@PathVariable Long id)
```

## GamificationController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/gamification` | [state](../backend/src/main/java/com/ecovision/backend/controller/GamificationController.java#L34) | `GamificationResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/gamification/avatar-tiers` | [avatarTiers](../backend/src/main/java/com/ecovision/backend/controller/GamificationController.java#L39) | `List<AvatarTierResponse>` | JSON / query / path; aşağıdaki imza |
| `PUT /api/gamification/avatar/{level}/equip` | [equipAvatar](../backend/src/main/java/com/ecovision/backend/controller/GamificationController.java#L44) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/gamification/carbon-footprint` | [completeCarbonFootprint](../backend/src/main/java/com/ecovision/backend/controller/GamificationController.java#L49) | `GamificationResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/gamification/redeem` | [redeem](../backend/src/main/java/com/ecovision/backend/controller/GamificationController.java#L59) | `GamificationResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
state()
avatarTiers()
equipAvatar(@PathVariable int level)
completeCarbonFootprint(@Valid @RequestBody CarbonFootprintRequest request)
redeem(@Valid @RequestBody RewardRedemptionRequest request)
```

## HealthController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/health` | [health](../backend/src/main/java/com/ecovision/backend/controller/HealthController.java#L9) | `String` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
health()
```

## LeaderboardController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/leaderboard/city` | [cityLeaderboard](../backend/src/main/java/com/ecovision/backend/controller/LeaderboardController.java#L25) | `List<CityLeaderboardEntry>` | JSON / query / path; aşağıdaki imza |
| `GET /api/leaderboard/friends` | [friendsLeaderboard](../backend/src/main/java/com/ecovision/backend/controller/LeaderboardController.java#L30) | `List<CityLeaderboardEntry>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
cityLeaderboard()
friendsLeaderboard()
```

## MapPinController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/map-pins/locations` | [locations](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L27) | `DoaLocationService.Inventory` | JSON / query / path; aşağıdaki imza |
| `GET /api/map-pins/search` | [search](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L30) | `DoaMapService.Page` | JSON / query / path; aşağıdaki imza |
| `GET /api/map-pins/nearby` | [nearby](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L45) | `List<DoaMapService.Point>` | JSON / query / path; aşağıdaki imza |
| `GET /api/map-pins/{id}` | [detail](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L59) | `DoaMapService.Detail` | JSON / query / path; aşağıdaki imza |
| `GET /api/map-pins` | [mapPins](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L64) | `List<MapPinResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/map-pins/nearest` | [nearestMapPins](../backend/src/main/java/com/ecovision/backend/controller/MapPinController.java#L69) | `List<MapPinResponse>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
locations()
search(@RequestParam double lat, @RequestParam double lng, @RequestParam(required = false) Double radiusKm, @RequestParam(defaultValue = "100") Integer limit, @RequestParam(defaultValue = "0") int offset, @RequestParam(defaultValue = "") Set<String> materials, @RequestParam(defaultValue = "DIM") Set<String> pointTypes, @RequestParam(defaultValue = "false") boolean openOnly, @RequestParam(required = false) String city, @RequestParam(required = false) String district, @RequestParam(required = false) Double south, @RequestParam(required = false) Double north, @RequestParam(required = false) Double west, @RequestParam(required = false) Double east)
nearby(@RequestParam double lat, @RequestParam double lng, @RequestParam(required = false) Double radiusKm, @RequestParam(required = false) Integer limit, @RequestParam(defaultValue = "") Set<String> materials, @RequestParam(defaultValue = "DIM") Set<String> pointTypes, @RequestParam(defaultValue = "false") boolean openOnly, @RequestParam(required = false) Double south, @RequestParam(required = false) Double north, @RequestParam(required = false) Double west, @RequestParam(required = false) Double east)
detail(@org.springframework.web.bind.annotation.PathVariable Long id)
mapPins()
nearestMapPins(@RequestParam double lat, @RequestParam double lng, @RequestParam(required = false) Double radiusKm, @RequestParam(required = false) Integer limit, @RequestParam(required = false, defaultValue = "") Set<String> materials)
```

## MarketController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `POST /api/market/purchase/{itemId}` | [purchase](../backend/src/main/java/com/ecovision/backend/controller/MarketController.java#L25) | `UserResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
purchase(@PathVariable String itemId)
```

## MediaController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/media/{id}` | [get](../backend/src/main/java/com/ecovision/backend/controller/MediaController.java#L32) | `ResponseEntity<byte[]>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
get(@PathVariable UUID id, @RequestParam(defaultValue = "false") boolean download, @org.springframework.security.core.annotation.AuthenticationPrincipal com.ecovision.backend.model.AppUser viewer)
```

## NotificationController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/notifications` | [list](../backend/src/main/java/com/ecovision/backend/controller/NotificationController.java#L15) | `List<NotificationResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/notifications/unread-count` | [unread](../backend/src/main/java/com/ecovision/backend/controller/NotificationController.java#L16) | `Map<String, Long>` | JSON / query / path; aşağıdaki imza |
| `POST /api/notifications/read-all` | [readAll](../backend/src/main/java/com/ecovision/backend/controller/NotificationController.java#L17) | `Map<String, Integer>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
list(@RequestParam(defaultValue = "50") int limit)
unread()
readAll()
```

## QuestController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/quests` | [catalog](../backend/src/main/java/com/ecovision/backend/controller/QuestController.java#L28) | `List<QuestProgressResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/quests/{questId}/check-in` | [checkIn](../backend/src/main/java/com/ecovision/backend/controller/QuestController.java#L43) | `QuestProgressResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/quests/progress/{progressId}/claim` | [claim](../backend/src/main/java/com/ecovision/backend/controller/QuestController.java#L51) | `QuestClaimResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
catalog(@org.springframework.web.bind.annotation.RequestParam(defaultValue = "0") int offset, @org.springframework.web.bind.annotation.RequestParam(defaultValue = "200") int limit, @org.springframework.web.bind.annotation.RequestParam(defaultValue = "") String query, @org.springframework.web.bind.annotation.RequestParam(defaultValue = "") String domain)
checkIn(@PathVariable Long questId)
claim(@PathVariable Long progressId)
```

## RealtimeChatController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `STOMP SEND /app/groups/{groupId}/messages` | [send](../backend/src/main/java/com/ecovision/backend/controller/RealtimeChatController.java#L34) | `void` | JSON / query / path; aşağıdaki imza |
| `STOMP SEND /app/events/{eventId}/messages` | [sendEventMessage](../backend/src/main/java/com/ecovision/backend/controller/RealtimeChatController.java#L50) | `void` | JSON / query / path; aşağıdaki imza |
| `STOMP SEND /app/groups/{groupId}/typing` | [typing](../backend/src/main/java/com/ecovision/backend/controller/RealtimeChatController.java#L59) | `void` | JSON / query / path; aşağıdaki imza |
| `STOMP SEND /app/events/{eventId}/typing` | [eventTyping](../backend/src/main/java/com/ecovision/backend/controller/RealtimeChatController.java#L77) | `void` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
send(@DestinationVariable Long groupId, @Valid ChatMessageRequest request, Principal principal)
sendEventMessage(@DestinationVariable Long eventId, @Valid ChatMessageRequest request, Principal principal)
typing(@DestinationVariable Long groupId, TypingEventRequest request, Principal principal)
eventTyping(@DestinationVariable Long eventId, TypingEventRequest request, Principal principal)
```

## ScanController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `POST /api/scans/eligibility` | [eligibility](../backend/src/main/java/com/ecovision/backend/controller/ScanController.java#L26) | `com.ecovision.backend.service.PackagingEligibility.Result` | JSON / query / path; aşağıdaki imza |
| `GET /api/scans` | [scans](../backend/src/main/java/com/ecovision/backend/controller/ScanController.java#L45) | `List<ScanResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/scans` | [saveScan](../backend/src/main/java/com/ecovision/backend/controller/ScanController.java#L50) | `ScanResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/scans/analyze` | [analyze](../backend/src/main/java/com/ecovision/backend/controller/ScanController.java#L55) | `GeminiScanResponse` | multipart |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
eligibility(@RequestBody com.ecovision.backend.service.PackagingEligibility.Request request)
scans()
saveScan(@Valid @RequestBody ScanRequest request)
analyze(@RequestPart("image") MultipartFile image)
```

## SocialController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/social/users/search` | [search](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L37) | `List<UserDiscoveryResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/social/users/{id}` | [profile](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L45) | `PublicProfileResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/users/{id}/like` | [like](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L50) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/social/users/{id}/like` | [unlike](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L55) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/friends/{id}/request` | [requestFriend](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L60) | `FriendRequestResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/friends/requests/{id}/accept` | [acceptFriend](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L65) | `FriendRequestResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/friends/requests/{id}/reject` | [rejectFriend](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L70) | `FriendRequestResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/social/friends/{id}` | [removeFriend](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L75) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/social/friends` | [friends](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L80) | `List<SocialUserResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/social/friends/requests` | [requests](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L85) | `List<FriendRequestResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/groups/{eventId}/invites/{friendId}` | [invite](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L90) | `GroupInviteResponse` | JSON / query / path; aşağıdaki imza |
| `GET /api/social/group-invites` | [invites](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L102) | `List<GroupInviteResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/group-invites/{id}/accept` | [acceptInvite](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L107) | `GroupInviteResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/reports/users/{id}` | [reportUser](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L112) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/reports/groups/{id}` | [reportGroup](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L120) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/social/blocks/{id}` | [block](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L128) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/social/blocks/{id}` | [unblock](../backend/src/main/java/com/ecovision/backend/controller/SocialController.java#L133) | `SocialActionResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
search(@RequestParam String query)
profile(@PathVariable Long id)
like(@PathVariable Long id)
unlike(@PathVariable Long id)
requestFriend(@PathVariable Long id)
acceptFriend(@PathVariable Long id)
rejectFriend(@PathVariable Long id)
removeFriend(@PathVariable Long id)
friends()
requests()
invite(@PathVariable Long eventId, @PathVariable Long friendId)
invites()
acceptInvite(@PathVariable Long id)
reportUser(@PathVariable Long id, @Valid @RequestBody ReportRequest request)
reportGroup(@PathVariable Long id, @Valid @RequestBody ReportRequest request)
block(@PathVariable Long id)
unblock(@PathVariable Long id)
```

## SuperuserController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/superuser/reports` | [reports](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L19) | `List<ModerationReportResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/superuser/audit/chat/{groupId}` | [auditGroup](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L20) | `List<ChatMessageResponse>` | JSON / query / path; aşağıdaki imza |
| `GET /api/superuser/audit/user/{userId}` | [auditUser](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L21) | `List<ChatMessageResponse>` | JSON / query / path; aşağıdaki imza |
| `POST /api/superuser/broadcast` | [broadcast](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L22) | `Map<String,Integer>` | JSON / query / path; aşağıdaki imza |
| `POST /api/superuser/users/{userId}/ban` | [ban](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L23) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/superuser/users/{userId}/unban` | [unban](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L24) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `POST /api/superuser/users/{userId}/suspend` | [suspend](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L25) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `DELETE /api/superuser/groups/{groupId}` | [deleteGroup](../backend/src/main/java/com/ecovision/backend/controller/SuperuserController.java#L26) | `ResponseEntity<Void>` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
reports()
auditGroup(@PathVariable Long groupId, @RequestParam(defaultValue="100") int limit, @RequestParam(defaultValue="0") int offset)
auditUser(@PathVariable Long userId, @RequestParam(defaultValue="100") int limit, @RequestParam(defaultValue="0") int offset)
broadcast(@Valid @RequestBody BroadcastRequest body)
ban(@PathVariable Long userId)
unban(@PathVariable Long userId)
suspend(@PathVariable Long userId, @Valid @RequestBody SuspendUserRequest body)
deleteGroup(@PathVariable Long groupId)
```

## UserController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `GET /api/users/login-streak` | [loginStreak](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L34) | `com.ecovision.backend.service.LoginActivityService.Status` | JSON / query / path; aşağıdaki imza |
| `GET /api/users/login-history` | [loginHistory](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L39) | `com.ecovision.backend.service.LoginActivityService.History` | JSON / query / path; aşağıdaki imza |
| `PUT /api/users/profile` | [updateProfile](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L45) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `PUT /api/users/password` | [changePassword](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L50) | `Map<String, String>` | JSON / query / path; aşağıdaki imza |
| `PUT /api/users/privacy` | [updateVisibility](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L58) | `UserResponse` | JSON / query / path; aşağıdaki imza |
| `PUT /api/users/theme` | [updateTheme](../backend/src/main/java/com/ecovision/backend/controller/UserController.java#L65) | `UserResponse` | JSON / query / path; aşağıdaki imza |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
loginStreak()
loginHistory(@org.springframework.web.bind.annotation.RequestParam(required = false) String month)
updateProfile(@Valid @RequestBody UpdateProfileRequest request)
changePassword(@Valid @RequestBody ChangePasswordRequest request)
updateVisibility(@Valid @RequestBody ProfileVisibilityRequest request)
updateTheme(@Valid @RequestBody ThemePreferenceRequest request)
```

## UserProfilePictureController.java

| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |
|---|---|---|---|
| `POST /api/users/profile-picture` | [upload](../backend/src/main/java/com/ecovision/backend/controller/UserProfilePictureController.java#L27) | `UserResponse` | multipart |

İstek parametreleri (annotation'lar doğrulama ve alan adlarını gösterir):

```java
upload(@RequestParam("image") MultipartFile image)
```

## Yetkiyi nasıl okumalı?

Tablo yalnız mapping/handler imzalarını çıkarır. Yetki denetimi SecurityConfig,
SUPERUSER method annotation'ları, CurrentUserService ve iş servislerinin
yaş/üyelik/kurucu/yönetici/nesne sahipliği kontrolleriyle birlikte değerlendirilir.
Medya URL'sinin filtre katmanında permitAll olması, özel medya bytes'ına
anonim erişim olduğu anlamına gelmez: MediaAccessService nesne yetkisini denetler.

## DTO alan sözleşmeleri

Aşağıdaki record başlıkları dto klasörünün gerçek kaynaklarından alınır.
Java tipleri sayı/boolean/list/object yapısını gösterir. @JsonProperty varsa JSON anahtarı o annotation değeridir.
Record gövdesindeki ek getter alanları bu başlıklarda yer almaz; gerçek JSON daha fazla türetilmiş alan içerebilir.
Bunlar örnek hesap, gerçek token veya anahtar değerleri içermez. Servis içi nested record'lar ana rehberde ayrıca açıklanır.

### AddGroupMemberRequest

```java
record AddGroupMemberRequest(
        @NotBlank @Size(max = 40) String username
)
```

### ApiError

```java
record ApiError(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path
)
```

### AssignAdminRequest

```java
record AssignAdminRequest(@Email @NotBlank String email)
```

### AuthResponse

```java
record AuthResponse(
        String accessToken,
        String refreshToken,
        long accessTokenExpiresInSeconds,
        UserResponse user
)
```

### AvatarTierResponse

```java
record AvatarTierResponse(
        int level,
        String title,
        int requiredLifetimePoints,
        boolean unlocked,
        boolean equipped
)
```

### BadgeResponse

```java
record BadgeResponse(String type, String title, String description, Instant awardedAt)
```

### BroadcastRequest

```java
record BroadcastRequest(
        @NotBlank @Size(max = 140) String title,
        @NotBlank @Size(max = 1000) String message
)
```

### CarbonFootprintRequest

```java
record CarbonFootprintRequest(
        // Optional consumption entries can exceed the original survey range.
        // The reward remains fixed and claimable only once per account.
        @Min(0) @Max(50000000) int score
)
```

### ChangePasswordRequest

```java
record ChangePasswordRequest(
        @NotBlank String currentPassword,
        @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z0-9\\s]).{8,72}$",
                message = "8-72 karakter, büyük/küçük harf, rakam ve özel karakter içermelidir"
        )
        @NotBlank
        String newPassword
)
```

### ChatMessageRequest

```java
record ChatMessageRequest(
        @NotBlank @Size(max = 2000) String message,
        Long replyToMessageId
)
```

### ChatMessageResponse

```java
record ChatMessageResponse(
        Long id,
        Long eventId,
        Long groupId,
        Long groupEventId,
        Long senderId,
        String senderUsername,
        String senderName,
        Integer senderAvatarLevel,
        Integer senderHighestAvatarLevel,
        String senderProfilePictureUrl,
        String senderProfileImagePreference,
        String senderSelectedAvatarPath,
        boolean senderAdult,
        String senderProfileVisibility,
        String message,
        String imageUrl,
        String fileUrl,
        String fileName,
        Long fileSizeBytes,
        String contentType,
        String messageType,
        Instant timestamp,
        boolean deleted,
        Long replyToMessageId,
        Long replyToSenderId,
        String replyToSenderName,
        String replyToText,
        List<ChatReactionResponse> reactions,
        ChatPollResponse poll
)
```

### ChatPollOptionResponse

```java
record ChatPollOptionResponse(
        int index,
        String text,
        List<Long> voterIds
)
```

### ChatPollResponse

```java
record ChatPollResponse(
        Long id,
        String question,
        List<ChatPollOptionResponse> options,
        int totalVotes
)
```

### ChatReactionRequest

```java
record ChatReactionRequest(@NotBlank @Size(max = 12) String emoji)
```

### ChatReactionResponse

```java
record ChatReactionResponse(String emoji, List<Long> userIds)
```

### CityLeaderboardEntry

```java
record CityLeaderboardEntry(
        int rank,
        Long userId,
        String username,
        String fullName,
        String city,
        Integer totalPoints,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
        String friendshipStatus,
        boolean currentUser
)
```

### CommunityGroupRequest

```java
record CommunityGroupRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 2000) String description,
        @NotBlank @Size(max = 80) String city,
        @NotBlank @Size(max = 80) String district,
        @Size(max = 120) String neighborhood,
        @Min(2) @Max(200) Integer memberLimit,
        @Size(min = 4, max = 64) String joinCode,
        Boolean privateGroup
)
```

### CommunityGroupResponse

```java
record CommunityGroupResponse(
        Long id,
        Long creatorId,
        String creatorName,
        String name,
        String description,
        String city,
        String district,
        String neighborhood,
        String coverImageUrl,
        Integer memberLimit,
        long memberCount,
        boolean privateGroup,
        String currentUserRole,
        String joinRequestStatus,
        String inviteCode,
        Long pinnedMessageId,
        String pinnedMessageText,
        Long pinnedEventId,
        Instant createdAt
)
```

### CreatePollRequest

```java
record CreatePollRequest(
        @NotBlank @Size(max = 300) String question,
        @Size(min = 2, max = 4) List<@NotBlank @Size(max = 160) String> options
)
```

### DetectedWasteResponse

```java
record DetectedWasteResponse(
        String type,
        String material,
        double confidence,
        @JsonProperty("machine_eligible")
        boolean machineEligible,
        @JsonProperty("eligibility_label")
        String eligibilityLabel
)
```

### EducationCompletionResponse

```java
record EducationCompletionResponse(
        String categoryId,
        boolean newlyCompleted,
        int pointsAwarded,
        int totalPoints,
        String message
)
```

### EventAttendeeResponse

```java
record EventAttendeeResponse(
        Long userId,
        String fullName,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
)
```

### EventMemberResponse

```java
record EventMemberResponse(
        Long userId,
        String username,
        String fullName,
        String role,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profilePictureUrl,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
)
```

### EventRequest

```java
record EventRequest(
        @NotBlank String title,
        @NotBlank String description,
        @NotBlank String city,
        @NotBlank String district,
        @NotBlank String neighborhood,
        @NotNull Instant eventDate,
        @NotNull LocalTime eventTime,
        @NotBlank @Size(max = 500) String exactAddress,
        @Min(2) @Max(200) Integer memberLimit,
        String joinCode
)
```

### EventResponse

```java
record EventResponse(
        Long id,
        Long creatorId,
        Long adminId,
        String creatorName,
        String title,
        String description,
        String location,
        String city,
        String district,
        String neighborhood,
        Instant eventDate,
        LocalTime eventTime,
        String exactAddress,
        String coverImageUrl,
        Integer memberLimit,
        long memberCount,
        long attendeeCount,
        boolean privateGroup,
        String currentUserRole,
        String currentUserAttendance
)
```

### EventRsvpRequest

```java
record EventRsvpRequest(@NotNull AttendanceStatus status)
```

### EventTypingEventResponse

```java
record EventTypingEventResponse(
        Long eventId,
        Long userId,
        String username,
        String fullName,
        boolean typing,
        Instant expiresAt
)
```

### ForgotPasswordRequest

```java
record ForgotPasswordRequest(
        @NotBlank @Email @Size(max = 254) String email
)
```

### FriendRequestResponse

```java
record FriendRequestResponse(
        Long id, SocialUserResponse requester, SocialUserResponse addressee,
        String status, Instant createdAt
)
```

### GamificationResponse

```java
record GamificationResponse(
        int totalPoints,
        boolean carbonFootprintCompleted,
        Set<String> redeemedRewardKeys,
        int pointsAwarded,
        String badge,
        String message
)
```

### GeminiScanResponse

```java
record GeminiScanResponse(
        List<DetectedWasteResponse> detections,
        ScanAnalysisResponse scan,
        @JsonProperty("updated_user_points")
        int updatedUserPoints,
        String provider,
        String modelVersion,
        String inferenceMode,
        boolean needsConfirmation
)
```

### GoogleAuthRequest

```java
record GoogleAuthRequest(
        @NotBlank String idToken,
        @Email @NotBlank String email,
        String name,
        String surname,
        String profilePictureUrl
)
```

### GroupEventAttendeeResponse

```java
record GroupEventAttendeeResponse(
        Long userId,
        String fullName,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
)
```

### GroupEventRequest

```java
record GroupEventRequest(
        @NotBlank @Size(max = 140) String title,
        @NotBlank @Size(max = 2000) String description,
        @NotNull @Future Instant eventDate,
        @NotBlank @Size(max = 80) String city,
        @NotBlank @Size(max = 80) String district,
        @NotBlank @Size(max = 500) String exactAddress,
        @Min(2) @Max(500) Integer capacity
)
```

### GroupEventResponse

```java
record GroupEventResponse(
        Long id,
        Long groupId,
        Long creatorId,
        String creatorName,
        String title,
        String description,
        Instant eventDate,
        String city,
        String district,
        String exactAddress,
        String coverImageUrl,
        Integer capacity,
        long attendeeCount,
        String currentUserAttendance,
        List<GroupEventAttendeeResponse> attendees,
        Instant createdAt
)
```

### GroupInviteResponse

```java
record GroupInviteResponse(
        Long id, Long eventId, String eventTitle, String location,
        SocialUserResponse inviter, String status, Instant createdAt
)
```

### GroupJoinRequestResponse

```java
record GroupJoinRequestResponse(
        Long id,
        Long groupId,
        Long userId,
        String username,
        String fullName,
        String profilePictureUrl,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
        String status,
        Instant requestedAt
)
```

### GroupMemberResponse

```java
record GroupMemberResponse(
        Long userId,
        String username,
        String fullName,
        String role,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profilePictureUrl,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility
)
```

### GroupMissionRequest

```java
record GroupMissionRequest(
        @NotBlank String title,
        @Min(1) @Max(1_000_000) int targetAmount,
        @NotBlank String unit
)
```

### GroupMissionResponse

```java
record GroupMissionResponse(
        Long id,
        Long eventId,
        String title,
        Integer targetAmount,
        Integer currentAmount,
        String unit,
        Instant createdAt
)
```

### GroupWasteReportRequest

```java
record GroupWasteReportRequest(
        @NotBlank String materialType,
        @Min(1) @Max(100_000) int itemCount
)
```

### GroupWasteReportResponse

```java
record GroupWasteReportResponse(
        Long id,
        Long eventId,
        Long reporterId,
        String reporterName,
        String materialType,
        Integer itemCount,
        Instant reportedAt
)
```

### JoinEventRequest

```java
record JoinEventRequest(String joinCode)
```

### LoginRequest

```java
record LoginRequest(
        @Email @NotBlank @Size(max = 254) String email,
        @NotBlank @Size(max = 72) String password
)
```

### MapPinBinResponse

```java
record MapPinBinResponse(
        String contentType,
        int level,
        boolean state
)
```

### MapPinRequest

```java
record MapPinRequest(
        @NotBlank String title,
        @NotNull Double latitude,
        @NotNull Double longitude
)
```

### MapPinResponse

```java
record MapPinResponse(
        Long id,
        String title,
        Double latitude,
        Double longitude,
        String type,
        Long createdById,
        String createdByName,
        Instant createdAt,
        Double distanceKm,
        String address,
        Set<String> acceptedMaterials,
        Map<String, Boolean> binStates,
        List<MapPinBinResponse> binList,
        boolean active
)
```

### ModerationReportResponse

```java
record ModerationReportResponse(
        Long id, Long reporterId, String reporterName,
        Long reportedUserId, String reportedUserName,
        Long groupId, String groupTitle,
        String reason, String details, String status, Instant createdAt
)
```

### NotificationResponse

```java
record NotificationResponse(Long id, String title, String message, String type, boolean read, Instant createdAt)
```

### PinGroupContentRequest

```java
record PinGroupContentRequest(
        @NotBlank
        @Pattern(regexp = "MESSAGE|EVENT|NONE")
        String type,
        Long id
)
```

### PollVoteRequest

```java
record PollVoteRequest(@Min(0) @Max(3) int optionIndex)
```

### ProfileVisibilityRequest

```java
record ProfileVisibilityRequest(@NotNull ProfileVisibility visibility)
```

### PublicProfileResponse

```java
record PublicProfileResponse(
        Long id, String username, String fullName, String profilePictureUrl,
        String profileImagePreference, String selectedAvatarPath,
        boolean adult, String city, Integer avatarLevel,
        Integer highestAvatarLevel, Integer totalPoints, Integer lifetimePoints,
        Integer streakCount, long likeCount, boolean likedByCurrentUser,
        String friendshipStatus, Long friendshipId, boolean blockedByCurrentUser,
        String profileVisibility, boolean detailsVisible,
        List<BadgeResponse> badges
)
```

### QuestClaimResponse

```java
record QuestClaimResponse(
        QuestProgressResponse quest,
        int pointsAwarded,
        int totalPoints,
        String message
)
```

### QuestProgressResponse

```java
record QuestProgressResponse(
        Long questId,
        Long progressId,
        String code,
        String title,
        String description,
        int rewardPoints,
        int targetAmount,
        String schedule,
        String domain,
        int currentAmount,
        boolean completed,
        boolean claimed,
        boolean checkInAvailable,
        Instant expiresAt,
        java.util.Map<String, Object> details
)
```

### RefreshTokenRequest

```java
record RefreshTokenRequest(@NotBlank String refreshToken)
```

### RegisterRequest

```java
record RegisterRequest(
        @NotBlank @Size(max = 60)
        @Pattern(regexp = "^[\\p{L} .'-]+$", message = "geçersiz karakter içeriyor")
        String name,
        @NotBlank @Size(max = 60)
        @Pattern(regexp = "^[\\p{L} .'-]+$", message = "geçersiz karakter içeriyor")
        String surname,
        @Email @NotBlank @Size(max = 254) String email,
        @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z0-9\\s]).{8,72}$",
                message = "8-72 karakter, büyük/küçük harf, rakam ve özel karakter içermelidir"
        )
        String password,
        @NotNull @Past LocalDate dateOfBirth,
        @NotBlank @Size(max = 60) String city,
        @NotBlank @Size(max = 60) String district,
        @Pattern(
                regexp = "^[a-z0-9_]{3,30}$",
                message = "3-30 karakter olmalı ve yalnızca küçük harf, rakam veya alt çizgi içermelidir"
        )
        String username,
        @AssertTrue(message = "kabul edilmelidir") boolean termsAccepted,
        @AssertTrue(message = "kabul edilmelidir") boolean privacyAccepted
)
```

### ReportRequest

```java
record ReportRequest(
        @NotBlank @Size(max = 80) String reason,
        @Size(max = 1000) String details
)
```

### RewardRedemptionRequest

```java
record RewardRedemptionRequest(
        @NotBlank String rewardKey
)
```

### ScanAnalysisRequest

```java
record ScanAnalysisRequest(
        @JsonProperty("detected_class")
        @NotBlank
        String detectedClass
)
```

### ScanAnalysisResponse

```java
record ScanAnalysisResponse(
        Long id,
        String material,
        @JsonProperty("is_recyclable")
        Boolean isRecyclable,
        @JsonProperty("decay_years")
        String decayYears,
        @JsonProperty("recycled_into")
        String recycledInto,
        Instant scannedAt,
        @JsonProperty("points_awarded")
        Integer pointsAwarded,
        @JsonProperty("updated_user_points")
        Integer updatedUserPoints,
        java.util.UUID analysisId,
        String rewardStatus
)
```

### ScanRequest

```java
record ScanRequest(
        @NotBlank @jakarta.validation.constraints.Size(max=100) String materialType,
        @NotNull Boolean recyclable
)
```

### ScanResponse

```java
record ScanResponse(
        Long id,
        Long userId,
        String materialType,
        Boolean recyclable,
        String decayYears,
        String recycledInto,
        Integer pointsAwarded,
        Instant scannedAt
)
```

### SocialActionResponse

```java
record SocialActionResponse(boolean success, String message)
```

### SocialUserResponse

```java
record SocialUserResponse(
        Long id, String username, String fullName, String profilePictureUrl, String city,
        Integer avatarLevel, Integer highestAvatarLevel,
        String profileImagePreference, String selectedAvatarPath, boolean adult,
        String profileVisibility, Long friendshipId, String friendshipStatus
)
```

### SuspendUserRequest

```java
record SuspendUserRequest(@Min(1) @Max(365) int days)
```

### ThemePreferenceRequest

```java
record ThemePreferenceRequest(
        @NotBlank
        @Pattern(
                regexp = "forest|ocean|sunset|darkEco",
                message = "Desteklenmeyen tema tercihi"
        )
        String themePreference
)
```

### TypingEventRequest

```java
record TypingEventRequest(boolean typing)
```

### TypingEventResponse

```java
record TypingEventResponse(
        Long groupId,
        Long userId,
        String username,
        String fullName,
        boolean typing,
        Instant expiresAt
)
```

### UpdateCommunityGroupRequest

```java
record UpdateCommunityGroupRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 2000) String description,
        @NotBlank @Size(max = 80) String city,
        @NotBlank @Size(max = 80) String district,
        @Size(max = 120) String neighborhood,
        @Min(2) @Max(200) Integer memberLimit,
        Boolean privateGroup,
        @Size(min = 4, max = 64) String joinCode
)
```

### UpdateProfileRequest

```java
record UpdateProfileRequest(
        @NotBlank String name,
        @NotBlank String surname,
        @Min(13) Integer age,
        @NotBlank String city,
        @NotBlank String district,
        @NotBlank String neighborhood,
        @Pattern(
                regexp = "^[a-z0-9_]{3,30}$",
                message = "3-30 karakter olmalı ve yalnızca küçük harf, rakam veya alt çizgi içermelidir"
        )
        String username
)
```

### UserDiscoveryResponse

```java
record UserDiscoveryResponse(
        Long id,
        String username,
        String fullName,
        String profilePictureUrl,
        String city,
        Integer avatarLevel,
        Integer highestAvatarLevel,
        String profileImagePreference,
        String selectedAvatarPath,
        boolean adult,
        String profileVisibility,
        Long friendshipId,
        String friendshipStatus
)
```

### UserResponse

```java
record UserResponse(
        Long id,
        String username,
        String name,
        String surname,
        String email,
        Integer age,
        String city,
        String district,
        String neighborhood,
        String themePreference,
        String profilePictureUrl,
        String profileImagePreference,
        String selectedAvatarPath,
        Integer equippedAvatarLevel,
        Integer currentAvatarLevel,
        Integer totalPoints,
        Integer lifetimePoints,
        boolean adult,
        Integer streakCount,
        Integer streakFreezeCount,
        LocalDate lastScanDate,
        boolean banned,
        Instant suspendedUntil,
        String role,
        String profileVisibility,
        Set<String> ownedMarketItems
)
```
