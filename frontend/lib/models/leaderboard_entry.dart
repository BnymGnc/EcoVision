import '../core/media_url.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.fullName,
    required this.city,
    required this.totalPoints,
    required this.currentUser,
    this.username = '',
    this.avatarLevel = 1,
    this.highestAvatarLevel = 1,
    this.profileImagePreference = 'AVATAR',
    this.profileVisibility = 'FRIENDS_ONLY',
    this.selectedAvatarPath,
    this.adult = false,
    this.friendshipStatus,
    this.profilePictureUrl,
  });

  final int rank;
  final int userId;
  final String fullName;
  final String username;
  final String city;
  final int totalPoints;
  final String? profilePictureUrl;
  final bool currentUser;
  final int avatarLevel;
  final int highestAvatarLevel;
  final String profileImagePreference;
  final String profileVisibility;
  final String? selectedAvatarPath;
  final bool adult;
  final String? friendshipStatus;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: (json['username'] ?? '').toString(),
      fullName: (json['fullName'] ?? 'EcoVision User').toString(),
      city: (json['city'] ?? '').toString(),
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
      currentUser: json['currentUser'] as bool? ?? false,
      avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
      highestAvatarLevel:
          (json['highestAvatarLevel'] as num? ??
                  json['avatarLevel'] as num? ??
                  1)
              .toInt(),
      profileImagePreference:
          (json['profileImagePreference'] ??
                  (json['profilePictureUrl'] == null
                      ? 'AVATAR'
                      : 'CUSTOM_PHOTO'))
              .toString(),
      profileVisibility: (json['profileVisibility'] ?? 'FRIENDS_ONLY')
          .toString(),
      selectedAvatarPath: json['selectedAvatarPath']?.toString(),
      adult: json['adult'] as bool? ?? false,
      friendshipStatus: json['friendshipStatus']?.toString(),
    );
  }
}
