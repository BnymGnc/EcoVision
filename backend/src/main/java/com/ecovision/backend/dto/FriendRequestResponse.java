package com.ecovision.backend.dto;

import com.ecovision.backend.model.Friendship;
import java.time.Instant;

public record FriendRequestResponse(
        Long id, SocialUserResponse requester, SocialUserResponse addressee,
        String status, Instant createdAt
) {
    public static FriendRequestResponse from(Friendship friendship) {
        return new FriendRequestResponse(friendship.getId(),
                SocialUserResponse.from(friendship.getRequester(), friendship.getId()),
                SocialUserResponse.from(friendship.getAddressee(), friendship.getId()),
                friendship.getStatus().name(), friendship.getCreatedAt());
    }
}
