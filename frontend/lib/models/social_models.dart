import '../core/media_url.dart';

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
    this.highestAvatarLevel = 1,
    this.profileImagePreference = 'AVATAR',
    this.username = '',
    this.profileVisibility = 'FRIENDS_ONLY',
    this.selectedAvatarPath,
    this.adult = false,
    this.profilePictureUrl,
    this.friendshipId,
    this.friendshipStatus,
  });
  final int id;
  final String fullName;
  final String username;
  final String city;
  final int avatarLevel;
  final int highestAvatarLevel;
  final String profileImagePreference;
  final String profileVisibility;
  final String? selectedAvatarPath;
  final bool adult;
  final String? profilePictureUrl;
  final int? friendshipId;
  final String? friendshipStatus;
  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    id: (json['id'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    highestAvatarLevel:
        (json['highestAvatarLevel'] as num? ?? json['avatarLevel'] as num? ?? 1)
            .toInt(),
    profileImagePreference:
        (json['profileImagePreference'] ??
                (json['profilePictureUrl'] == null ? 'AVATAR' : 'CUSTOM_PHOTO'))
            .toString(),
    profileVisibility: (json['profileVisibility'] ?? 'FRIENDS_ONLY').toString(),
    selectedAvatarPath: json['selectedAvatarPath']?.toString(),
    adult: json['adult'] as bool? ?? false,
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
    friendshipId: (json['friendshipId'] as num?)?.toInt(),
    friendshipStatus: json['friendshipStatus']?.toString(),
  );
}

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.fullName,
    required this.city,
    required this.avatarLevel,
    this.highestAvatarLevel = 1,
    required this.totalPoints,
    required this.streakCount,
    required this.likeCount,
    required this.liked,
    required this.blocked,
    required this.badges,
    this.username = '',
    this.profileVisibility = 'PUBLIC',
    this.profileImagePreference = 'AVATAR',
    this.selectedAvatarPath,
    this.adult = false,
    this.detailsVisible = true,
    this.profilePictureUrl,
    this.friendshipStatus,
    this.friendshipId,
  });
  final int id;
  final String fullName;
  final String username;
  final String city;
  final int avatarLevel;
  final int highestAvatarLevel;
  final int totalPoints;
  final int streakCount;
  final int likeCount;
  final bool liked;
  final bool blocked;
  final String? profilePictureUrl;
  final String? friendshipStatus;
  final int? friendshipId;
  final List<EcoBadge> badges;
  final String profileVisibility;
  final String profileImagePreference;
  final String? selectedAvatarPath;
  final bool adult;
  final bool detailsVisible;
  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: (json['id'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    highestAvatarLevel:
        (json['highestAvatarLevel'] as num? ?? json['avatarLevel'] as num? ?? 1)
            .toInt(),
    totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
    streakCount: (json['streakCount'] as num? ?? 0).toInt(),
    likeCount: (json['likeCount'] as num? ?? 0).toInt(),
    liked: json['likedByCurrentUser'] as bool? ?? false,
    blocked: json['blockedByCurrentUser'] as bool? ?? false,
    profileVisibility: (json['profileVisibility'] ?? 'PUBLIC').toString(),
    profileImagePreference:
        (json['profileImagePreference'] ??
                (json['profilePictureUrl'] == null ? 'AVATAR' : 'CUSTOM_PHOTO'))
            .toString(),
    selectedAvatarPath: json['selectedAvatarPath']?.toString(),
    adult: json['adult'] as bool? ?? false,
    detailsVisible: json['detailsVisible'] as bool? ?? true,
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
    friendshipStatus: json['friendshipStatus']?.toString(),
    friendshipId: (json['friendshipId'] as num?)?.toInt(),
    badges: (json['badges'] as List? ?? const [])
        .map((e) => EcoBadge.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class UserDiscovery {
  const UserDiscovery({
    required this.id,
    required this.username,
    required this.fullName,
    required this.city,
    required this.avatarLevel,
    this.highestAvatarLevel = 1,
    required this.profileVisibility,
    this.profileImagePreference = 'AVATAR',
    this.selectedAvatarPath,
    this.adult = false,
    this.profilePictureUrl,
    this.friendshipId,
    this.friendshipStatus,
  });

  final int id;
  final String username;
  final String fullName;
  final String city;
  final int avatarLevel;
  final int highestAvatarLevel;
  final String profileVisibility;
  final String profileImagePreference;
  final String? selectedAvatarPath;
  final bool adult;
  final String? profilePictureUrl;
  final int? friendshipId;
  final String? friendshipStatus;

  factory UserDiscovery.fromJson(Map<String, dynamic> json) => UserDiscovery(
    id: (json['id'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    highestAvatarLevel:
        (json['highestAvatarLevel'] as num? ?? json['avatarLevel'] as num? ?? 1)
            .toInt(),
    profileVisibility: (json['profileVisibility'] ?? 'PUBLIC').toString(),
    profileImagePreference:
        (json['profileImagePreference'] ??
                (json['profilePictureUrl'] == null ? 'AVATAR' : 'CUSTOM_PHOTO'))
            .toString(),
    selectedAvatarPath: json['selectedAvatarPath']?.toString(),
    adult: json['adult'] as bool? ?? false,
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
    friendshipId: (json['friendshipId'] as num?)?.toInt(),
    friendshipStatus: json['friendshipStatus']?.toString(),
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
