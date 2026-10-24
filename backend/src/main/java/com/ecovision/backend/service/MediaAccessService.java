package com.ecovision.backend.service;

import com.ecovision.backend.model.*;
import com.ecovision.backend.repository.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class MediaAccessService {
    private final JdbcTemplate jdbc;
    private final AppUserRepository users;
    private final FriendshipRepository friends;
    private final UserBlockRepository blocks;
    public MediaAccessService(JdbcTemplate jdbc, AppUserRepository users,
                              FriendshipRepository friends, UserBlockRepository blocks) {
        this.jdbc = jdbc; this.users = users; this.friends = friends; this.blocks = blocks;
    }

    // Resolve against current domain references, never a cached visibility flag.
    // Legacy rows with no owner are evaluated through their existing references.
    @Transactional(readOnly = true)
    public void requireAccess(UUID id, String category, Long uploader, AppUser viewer) {
        String path = "/api/media/" + id;
        if (viewer != null && (!viewer.isEnabled() || !viewer.isAccountNonLocked())) deny(viewer);
        switch (category) {
            case "profiles" -> {
                var owners = uploader != null ? List.of(uploader) : jdbc.queryForList(
                        "select id from users where right(split_part(profile_picture_url,'?',1), ?) = ?",
                        Long.class, path.length(), path);
                for (Long ownerId : owners) {
                    if (uploader != null && !uploader.equals(ownerId)) continue;
                    AppUser owner = users.findById(ownerId).orElse(null);
                    if (owner == null || owner.getProfilePictureUrl() == null
                            || !owner.getProfilePictureUrl().split("\\?",2)[0].endsWith(path)) continue;
                    if (owner == null || !owner.isAdult() || !owner.isEnabled()
                            || owner.getProfileImagePreference() != ProfileImagePreference.CUSTOM_PHOTO) continue;
                    if (viewer != null && viewer.getId().equals(ownerId)) return;
                    if (viewer != null && (blocks.existsByBlockerIdAndBlockedUserId(ownerId, viewer.getId())
                            || blocks.existsByBlockerIdAndBlockedUserId(viewer.getId(), ownerId))) continue;
                    if (owner.getProfileVisibility() == ProfileVisibility.PUBLIC) return;
                    if (viewer != null && friends.findBetween(ownerId, viewer.getId())
                            .map(f -> f.getStatus() == FriendshipStatus.ACCEPTED).orElse(false)) return;
                }
            }
            case "groups" -> {
                if (viewer == null || !viewer.isAdult()) break;
                var rows = jdbc.queryForList("""
                    select id, creator_id, private_group, join_code_hash from community_groups
                    where right(split_part(cover_image_url,'?',1), ?) = ?
                    """, path.length(), path);
                for (var row : rows) {
                    long creator = ((Number)row.get("creator_id")).longValue();
                    boolean secret = Boolean.TRUE.equals(row.get("private_group"))
                            || (row.get("join_code_hash") != null && !row.get("join_code_hash").toString().isBlank());
                    if (!secret || groupMember(((Number)row.get("id")).longValue(), creator, viewer)) return;
                }
            }
            case "group-events" -> {
                if (viewer == null || !viewer.isAdult()) break;
                var rows = jdbc.queryForList("""
                    select e.group_id, e.creator_id, g.creator_id as founder from group_events e
                    join community_groups g on g.id=e.group_id
                    where right(split_part(e.cover_image_url,'?',1), ?) = ?
                    """, path.length(), path);
                for (var row : rows) {
                    if (groupMember(((Number)row.get("group_id")).longValue(), ((Number)row.get("founder")).longValue(), viewer)) return;
                }
            }
            case "group-chat", "chat" -> {
                if (viewer == null || !viewer.isAdult()) break;
                var rows = jdbc.queryForList("""
                    select m.group_id,m.event_id,m.sender_id,g.creator_id as founder,e.creator_id as event_creator
                    from chat_messages m left join community_groups g on g.id=m.group_id
                    left join events e on e.id=m.event_id where m.deleted=false and
                    (right(split_part(m.image_url,'?',1),?)=? or right(split_part(m.file_url,'?',1),?)=?)
                    """, path.length(), path, path.length(), path);
                for (var row : rows) {
                    if (uploader != null && uploader.longValue() != ((Number)row.get("sender_id")).longValue()) continue;
                    if (row.get("group_id") != null && row.get("founder") != null &&
                            groupMember(((Number)row.get("group_id")).longValue(), ((Number)row.get("founder")).longValue(), viewer)) return;
                    if (row.get("event_id") != null && row.get("event_creator") != null &&
                            eventMember(((Number)row.get("event_id")).longValue(), ((Number)row.get("event_creator")).longValue(), viewer)) return;
                }
            }
            case "events" -> {
                if (viewer == null || !viewer.isAdult()) break;
                var rows = jdbc.queryForList("""
                    select id,creator_id from events where
                    right(split_part(cover_image_url,'?',1),?)=? or right(split_part(image_url,'?',1),?)=?
                    """, path.length(), path, path.length(), path);
                for (var row : rows) {
                    long creator = ((Number)row.get("creator_id")).longValue();
                    if (eventMember(((Number)row.get("id")).longValue(), creator, viewer)) return;
                }
            }
            default -> { /* Orphan/unknown categories are deliberately fail-closed. */ }
        }
        deny(viewer);
    }
    private boolean groupMember(long group, long founder, AppUser viewer) {
        return viewer.getRole() == Role.SUPERUSER || viewer.getId() == founder || Boolean.TRUE.equals(jdbc.queryForObject(
                "select exists(select 1 from group_members where group_id=? and user_id=?)",
                Boolean.class, group, viewer.getId()));
    }
    private boolean eventMember(long event, long creator, AppUser viewer) {
        var migrated = jdbc.queryForList("select id,creator_id from community_groups where legacy_event_id=?", event);
        if (!migrated.isEmpty()) {
            var group = migrated.get(0);
            return groupMember(((Number)group.get("id")).longValue(),
                    ((Number)group.get("creator_id")).longValue(), viewer);
        }
        return viewer.getRole() == Role.SUPERUSER || viewer.getId() == creator || Boolean.TRUE.equals(jdbc.queryForObject(
                "select exists(select 1 from event_members where event_id=? and user_id=?)",
                Boolean.class, event, viewer.getId()));
    }
    private void deny(AppUser viewer) {
        throw new ResponseStatusException(viewer == null ? HttpStatus.UNAUTHORIZED : HttpStatus.FORBIDDEN,
                "Bu medya için erişim iznin yok");
    }
}
