class EcoBadge {
  const EcoBadge({
    required this.type,
    required this.title,
    required this.description,
  });
  final String type;
  final String title;
  final String description;
  factory EcoBadge.fromJson(Map<String, dynamic> json) => EcoBadge(
    type: (json['type'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
  );
}

class SocialUser {
  const SocialUser({
    required this.id,
    required this.fullName,
    required this.city,
    required this.avatarLevel,
    this.profilePictureUrl,
    this.friendshipId,
  });
  final int id;
  final String fullName;
  final String city;
  final int avatarLevel;
  final String? profilePictureUrl;
  final int? friendshipId;
  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    id: (json['id'] as num).toInt(),
    fullName: (json['fullName'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    profilePictureUrl: json['profilePictureUrl']?.toString(),
    friendshipId: (json['friendshipId'] as num?)?.toInt(),
  );
}

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.fullName,
    required this.city,
    required this.avatarLevel,
    required this.totalPoints,
    required this.streakCount,
    required this.likeCount,
    required this.liked,
    required this.blocked,
    required this.badges,
    this.profilePictureUrl,
    this.friendshipStatus,
    this.friendshipId,
  });
  final int id;
  final String fullName;
  final String city;
  final int avatarLevel;
  final int totalPoints;
  final int streakCount;
  final int likeCount;
  final bool liked;
  final bool blocked;
  final String? profilePictureUrl;
  final String? friendshipStatus;
  final int? friendshipId;
  final List<EcoBadge> badges;
  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: (json['id'] as num).toInt(),
    fullName: (json['fullName'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
    streakCount: (json['streakCount'] as num? ?? 0).toInt(),
    likeCount: (json['likeCount'] as num? ?? 0).toInt(),
    liked: json['likedByCurrentUser'] as bool? ?? false,
    blocked: json['blockedByCurrentUser'] as bool? ?? false,
    profilePictureUrl: json['profilePictureUrl']?.toString(),
    friendshipStatus: json['friendshipStatus']?.toString(),
    friendshipId: (json['friendshipId'] as num?)?.toInt(),
    badges: (json['badges'] as List? ?? const [])
        .map((e) => EcoBadge.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.requester,
    required this.status,
  });
  final int id;
  final SocialUser requester;
  final String status;
  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: (json['id'] as num).toInt(),
    requester: SocialUser.fromJson(json['requester'] as Map<String, dynamic>),
    status: (json['status'] ?? '').toString(),
  );
}

class GroupInviteModel {
  const GroupInviteModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.location,
    required this.inviter,
  });
  final int id;
  final int eventId;
  final String eventTitle;
  final String location;
  final SocialUser inviter;
  factory GroupInviteModel.fromJson(Map<String, dynamic> json) =>
      GroupInviteModel(
        id: (json['id'] as num).toInt(),
        eventId: (json['eventId'] as num).toInt(),
        eventTitle: (json['eventTitle'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        inviter: SocialUser.fromJson(json['inviter'] as Map<String, dynamic>),
      );
}
