package com.ecovision.backend.service;

import com.ecovision.backend.dto.*;
import com.ecovision.backend.model.*;
import com.ecovision.backend.repository.*;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Locale;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SocialService {
    private final AppUserRepository users;
    private final FriendshipRepository friendships;
    private final ProfileLikeRepository likes;
    private final UserBlockRepository blocks;
    private final GroupInviteRepository invites;
    private final SocialReportRepository reports;
    private final EventRepository events;
    private final EventMemberRepository members;
    private final AgeGateService ageGate;
    private final BadgeService badges;
    private final NotificationService notifications;

    public SocialService(AppUserRepository users, FriendshipRepository friendships,
                         ProfileLikeRepository likes, UserBlockRepository blocks,
                         GroupInviteRepository invites, SocialReportRepository reports,
                         EventRepository events, EventMemberRepository members,
                         AgeGateService ageGate, BadgeService badges, NotificationService notifications) {
        this.users = users; this.friendships = friendships; this.likes = likes; this.blocks = blocks;
        this.invites = invites; this.reports = reports; this.events = events; this.members = members;
        this.ageGate = ageGate; this.badges = badges;
        this.notifications = notifications;
    }

    @Transactional(readOnly = true)
    public PublicProfileResponse profile(AppUser current, Long userId) {
        if (!current.getId().equals(userId)) ageGate.requireAdult(current);
        AppUser target = user(userId);
        Friendship friendship = friendships.findBetween(current.getId(), userId).orElse(null);
        boolean detailsVisible = current.getId().equals(userId)
                || target.getProfileVisibility() == ProfileVisibility.PUBLIC
                || isAccepted(friendship);
        if (!current.getId().equals(userId)) {
            if (!target.isAdult()) {
                throw new IllegalArgumentException("Kullanıcı bulunamadı");
            }
        }
        String visiblePhoto = target.isAdult() && detailsVisible
                && target.getProfileImagePreference()
                == ProfileImagePreference.CUSTOM_PHOTO
                ? target.getProfilePictureUrl()
                : null;
        return new PublicProfileResponse(target.getId(), target.getPublicUsername(),
                target.getName() + " " + target.getSurname(),
                visiblePhoto, target.getProfileImagePreference().name(),
                target.getSelectedAvatarPath(), target.isAdult(),
                target.getCity(), target.getEquippedAvatarLevel(),
                AvatarTier.highestUnlocked(target.getLifetimePoints()).level(),
                detailsVisible ? target.getTotalPoints() : 0,
                detailsVisible ? target.getLifetimePoints() : 0,
                detailsVisible ? target.getStreakCount() : 0,
                likes.countByLikedUserId(userId), likes.existsByLikerIdAndLikedUserId(current.getId(), userId),
                friendship == null ? null : friendship.getStatus().name(),
                friendship == null ? null : friendship.getId(),
                blocks.existsByBlockerIdAndBlockedUserId(current.getId(), userId),
                target.getProfileVisibility().name(), detailsVisible,
                detailsVisible ? badges.getBadges(userId) : List.of());
    }

    @Transactional(readOnly = true)
    public List<UserDiscoveryResponse> searchUsers(AppUser current, String query) {
        ageGate.requireAdult(current);
        String normalized = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        if (normalized.length() < 3) {
            throw new IllegalArgumentException(
                    "Kullanıcı araması en az 3 karakter olmalıdır"
            );
        }
        return users.searchAdultUsers(
                        normalized,
                        LocalDate.now().minusYears(18),
                        PageRequest.of(0, 20)
                ).stream()
                .filter(target -> !current.getId().equals(target.getId()))
                .filter(target -> !blockedEitherWay(
                        current.getId(),
                        target.getId()
                ))
                .map(target -> UserDiscoveryResponse.from(
                        target,
                        friendships.findBetween(
                                current.getId(),
                                target.getId()
                        ).orElse(null)
                ))
                .toList();
    }

    @Transactional
    public SocialActionResponse like(AppUser current, Long targetId) {
        requireOther(current, targetId); AppUser target = user(targetId);
        if (!likes.existsByLikerIdAndLikedUserId(current.getId(), targetId)) {
            ProfileLike like = new ProfileLike(); like.setLiker(current); like.setLikedUser(target); likes.save(like);
            notifications.notifyUser(target, "Profilin beğenildi", current.getName() + " profilini beğendi.", NotificationType.SOCIAL);
            badges.evaluateLikes(target);
        }
        return new SocialActionResponse(true, "Profil beğenildi");
    }

    @Transactional
    public SocialActionResponse unlike(AppUser current, Long targetId) {
        ageGate.requireAdult(current); likes.deleteByLikerIdAndLikedUserId(current.getId(), targetId);
        return new SocialActionResponse(true, "Beğeni kaldırıldı");
    }

    @Transactional
    public FriendRequestResponse requestFriend(AppUser current, Long targetId) {
        requireOther(current, targetId); AppUser target = user(targetId); ageGate.requireAdult(target);
        if (blockedEitherWay(current.getId(), targetId)) throw new IllegalArgumentException("Bu kullanıcıyla etkileşim kurulamıyor");
        Friendship existing = friendships.findBetween(current.getId(), targetId).orElse(null);
        if (existing != null && existing.getStatus() != FriendshipStatus.REJECTED) return FriendRequestResponse.from(existing);
        Friendship friendship = existing == null ? new Friendship() : existing;
        friendship.setRequester(current); friendship.setAddressee(target); friendship.setStatus(FriendshipStatus.PENDING);
        friendship.setRespondedAt(null);
        Friendship saved = friendships.save(friendship);
        notifications.notifyUser(target, "Yeni arkadaşlık isteği",
                current.getName() + " sana arkadaşlık isteği gönderdi.", NotificationType.SOCIAL);
        return FriendRequestResponse.from(saved);
    }

    @Transactional
    public FriendRequestResponse acceptFriend(AppUser current, Long requestId) {
        ageGate.requireAdult(current);
        Friendship friendship = friendships.findById(requestId).orElseThrow(() -> new IllegalArgumentException("Arkadaşlık isteği bulunamadı"));
        if (!friendship.getAddressee().getId().equals(current.getId())) throw new IllegalArgumentException("Bu isteği kabul edemezsiniz");
        friendship.setStatus(FriendshipStatus.ACCEPTED); friendship.setRespondedAt(Instant.now());
        Friendship saved = friendships.save(friendship);
        notifications.notifyUser(saved.getRequester(), "Arkadaşlık isteğin kabul edildi",
                current.getName() + " artık arkadaşın.", NotificationType.SOCIAL);
        return FriendRequestResponse.from(saved);
    }

    @Transactional
    public FriendRequestResponse rejectFriend(AppUser current, Long requestId) {
        ageGate.requireAdult(current);
        Friendship friendship = friendships.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Arkadaşlık isteği bulunamadı"));
        if (!friendship.getAddressee().getId().equals(current.getId())
                || friendship.getStatus() != FriendshipStatus.PENDING) {
            throw new IllegalArgumentException("Bu istek reddedilemez");
        }
        friendship.setStatus(FriendshipStatus.REJECTED);
        friendship.setRespondedAt(Instant.now());
        return FriendRequestResponse.from(friendships.save(friendship));
    }

    @Transactional
    public SocialActionResponse removeFriend(AppUser current, Long targetId) {
        requireOther(current, targetId);
        Friendship friendship = friendships.findBetween(current.getId(), targetId)
                .orElseThrow(() -> new IllegalArgumentException("Arkadaşlık bulunamadı"));
        if (friendship.getStatus() != FriendshipStatus.ACCEPTED) {
            throw new IllegalArgumentException("Kullanıcı arkadaş listenizde değil");
        }
        friendships.delete(friendship);
        return new SocialActionResponse(true, "Arkadaşlık kaldırıldı");
    }

    @Transactional(readOnly = true)
    public List<SocialUserResponse> friends(AppUser current) {
        ageGate.requireAdult(current);
        return friendships.findForUser(current.getId(), FriendshipStatus.ACCEPTED).stream()
                .map(f -> SocialUserResponse.from(
                        f.getRequester().getId().equals(current.getId())
                                ? f.getAddressee()
                                : f.getRequester(),
                        f.getId(),
                        f.getStatus().name()
                ))
                .filter(u -> !blockedEitherWay(current.getId(), u.id())).toList();
    }

    @Transactional(readOnly = true)
    public List<FriendRequestResponse> incomingRequests(AppUser current) {
        ageGate.requireAdult(current);
        return friendships.findByAddresseeIdAndStatusOrderByCreatedAtDesc(current.getId(), FriendshipStatus.PENDING)
                .stream().map(FriendRequestResponse::from).toList();
    }

    @Transactional
    public GroupInviteResponse inviteFriend(AppUser current, Long eventId, Long friendId) {
        ageGate.requireAdult(current); Event event = event(eventId); requireGroupAdmin(current, eventId);
        if (!event.isPrivateGroup()) throw new IllegalArgumentException("Davet sistemi yalnızca özel gruplarda kullanılır");
        Friendship friendship = friendships.findBetween(current.getId(), friendId).orElseThrow(() -> new IllegalArgumentException("Yalnızca arkadaşlar davet edilebilir"));
        if (friendship.getStatus() != FriendshipStatus.ACCEPTED) throw new IllegalArgumentException("Yalnızca arkadaşlar davet edilebilir");
        if (members.existsByEventIdAndUserId(eventId, friendId)) throw new IllegalArgumentException("Kullanıcı zaten grupta");
        if (invites.existsByEventIdAndInviteeIdAndStatus(eventId, friendId, InviteStatus.PENDING)) throw new IllegalArgumentException("Bekleyen bir davet zaten var");
        GroupInvite invite = new GroupInvite(); invite.setEvent(event); invite.setInviter(current); invite.setInvitee(user(friendId));
        GroupInvite saved = invites.save(invite);
        notifications.notifyUser(saved.getInvitee(), "Özel grup daveti", current.getName() + " seni " + event.getTitle() + " grubuna davet etti.", NotificationType.SOCIAL);
        return GroupInviteResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public List<GroupInviteResponse> groupInvites(AppUser current) {
        ageGate.requireAdult(current);
        return invites.findByInviteeIdAndStatusOrderByCreatedAtDesc(current.getId(), InviteStatus.PENDING).stream().map(GroupInviteResponse::from).toList();
    }

    @Transactional
    public GroupInviteResponse acceptInvite(AppUser current, Long inviteId) {
        ageGate.requireAdult(current); GroupInvite invite = invites.findWithRelationsById(inviteId).orElseThrow(() -> new IllegalArgumentException("Davet bulunamadı"));
        if (!invite.getInvitee().getId().equals(current.getId()) || invite.getStatus() != InviteStatus.PENDING) throw new IllegalArgumentException("Bu davet kullanılamaz");
        if (members.countByEventId(invite.getEvent().getId()) >= invite.getEvent().getMemberLimit()) throw new IllegalArgumentException("Grup dolu");
        EventMember member = new EventMember(); member.setEvent(invite.getEvent()); member.setUser(current); member.setRole(GroupRole.MEMBER); members.save(member);
        invite.setStatus(InviteStatus.ACCEPTED); invite.setRespondedAt(Instant.now()); return GroupInviteResponse.from(invites.save(invite));
    }

    @Transactional
    public SocialActionResponse reportUser(AppUser current, Long targetId, ReportRequest request) {
        requireOther(current, targetId); SocialReport report = report(current, request); report.setReportedUser(user(targetId)); reports.save(report);
        return new SocialActionResponse(true, "Kullanıcı bildirimi alındı");
    }

    @Transactional
    public SocialActionResponse reportGroup(AppUser current, Long eventId, ReportRequest request) {
        ageGate.requireAdult(current); SocialReport report = report(current, request); report.setReportedEvent(event(eventId)); reports.save(report);
        return new SocialActionResponse(true, "Grup bildirimi alındı");
    }

    @Transactional
    public SocialActionResponse block(AppUser current, Long targetId) {
        requireOther(current, targetId);
        if (!blocks.existsByBlockerIdAndBlockedUserId(current.getId(), targetId)) {
            UserBlock block = new UserBlock(); block.setBlocker(current); block.setBlockedUser(user(targetId)); blocks.save(block);
        }
        return new SocialActionResponse(true, "Kullanıcı engellendi");
    }

    @Transactional
    public SocialActionResponse unblock(AppUser current, Long targetId) {
        ageGate.requireAdult(current); blocks.deleteByBlockerIdAndBlockedUserId(current.getId(), targetId);
        return new SocialActionResponse(true, "Engel kaldırıldı");
    }

    private SocialReport report(AppUser current, ReportRequest request) { SocialReport r = new SocialReport(); r.setReporter(current); r.setReason(request.reason().trim()); r.setDetails(request.details()); return r; }
    private AppUser user(Long id) { return users.findById(id).orElseThrow(() -> new IllegalArgumentException("Kullanıcı bulunamadı")); }
    private Event event(Long id) { return events.findById(id).orElseThrow(() -> new IllegalArgumentException("Grup bulunamadı")); }
    private void requireOther(AppUser current, Long id) { ageGate.requireAdult(current); if (current.getId().equals(id)) throw new IllegalArgumentException("Kendi profilinizde bu işlem yapılamaz"); }
    private boolean blockedEitherWay(Long a, Long b) { return blocks.existsByBlockerIdAndBlockedUserId(a,b) || blocks.existsByBlockerIdAndBlockedUserId(b,a); }
    private boolean isAccepted(Friendship friendship) { return friendship != null && friendship.getStatus() == FriendshipStatus.ACCEPTED; }
    private void requireGroupAdmin(AppUser current, Long eventId) { if (members.findByEventIdAndUserId(eventId, current.getId()).map(m -> m.getRole() == GroupRole.GROUP_ADMIN).orElse(false) == false) throw new IllegalArgumentException("Yalnızca grup yöneticileri davet gönderebilir"); }
}
