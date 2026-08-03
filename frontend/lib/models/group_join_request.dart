import '../core/media_url.dart';

class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.status,
    required this.requestedAt,
    this.avatarLevel = 1,
    this.highestAvatarLevel = 1,
    this.profileImagePreference = 'AVATAR',
    this.selectedAvatarPath,
    this.adult = false,
    this.profileVisibility = 'FRIENDS_ONLY',
    this.profilePictureUrl,
  });

  final int id;
  final int groupId;
  final int userId;
  final String username;
  final String fullName;
  final String status;
  final DateTime requestedAt;
  final String? profilePictureUrl;
  final int avatarLevel;
  final int highestAvatarLevel;
  final String profileImagePreference;
  final String? selectedAvatarPath;
  final bool adult;
  final String profileVisibility;

  factory GroupJoinRequest.fromJson(
    Map<String, dynamic> json,
  ) => GroupJoinRequest(
    id: (json['id'] as num).toInt(),
    groupId: (json['groupId'] as num).toInt(),
    userId: (json['userId'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    status: (json['status'] ?? 'PENDING').toString(),
    requestedAt:
        DateTime.tryParse((json['requestedAt'] ?? '').toString()) ??
        DateTime.now(),
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    highestAvatarLevel:
        (json['highestAvatarLevel'] as num? ?? json['avatarLevel'] as num? ?? 1)
            .toInt(),
    profileImagePreference:
        (json['profileImagePreference'] ??
                (json['profilePictureUrl'] == null ? 'AVATAR' : 'CUSTOM_PHOTO'))
            .toString(),
    selectedAvatarPath: json['selectedAvatarPath']?.toString(),
    adult: json['adult'] as bool? ?? false,
    profileVisibility: (json['profileVisibility'] ?? 'FRIENDS_ONLY').toString(),
  );
}
