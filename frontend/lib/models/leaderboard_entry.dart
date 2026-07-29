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

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: (json['username'] ?? '').toString(),
      fullName: (json['fullName'] ?? 'EcoVision User').toString(),
      city: (json['city'] ?? 'Şanlıurfa').toString(),
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
      currentUser: json['currentUser'] as bool? ?? false,
    );
  }
}
