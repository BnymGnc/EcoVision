import '../core/media_url.dart';

class EventMember {
  const EventMember({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.avatarLevel,
    this.highestAvatarLevel = 1,
    this.profileImagePreference = 'AVATAR',
    this.profileVisibility = 'FRIENDS_ONLY',
    this.selectedAvatarPath,
    this.adult = false,
    this.friendshipStatus,
    this.profilePictureUrl,
  });

  final int userId;
  final String username;
  final String fullName;
  final String role;
  final int avatarLevel;
  final int highestAvatarLevel;
  final String profileImagePreference;
  final String profileVisibility;
  final String? selectedAvatarPath;
  final bool adult;
  final String? friendshipStatus;
  final String? profilePictureUrl;

  bool get isFounder => role == 'FOUNDER';
  bool get isAdmin => isFounder || role == 'ADMIN' || role == 'GROUP_ADMIN';

  factory EventMember.fromJson(Map<String, dynamic> json) => EventMember(
    userId: (json['userId'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    role: (json['role'] ?? 'MEMBER').toString(),
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
    friendshipStatus: json['friendshipStatus']?.toString(),
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
  );
}
