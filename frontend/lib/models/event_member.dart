import '../core/media_url.dart';

class EventMember {
  const EventMember({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.avatarLevel,
    this.profilePictureUrl,
  });

  final int userId;
  final String username;
  final String fullName;
  final String role;
  final int avatarLevel;
  final String? profilePictureUrl;

  bool get isFounder => role == 'FOUNDER';
  bool get isAdmin => isFounder || role == 'ADMIN' || role == 'GROUP_ADMIN';

  factory EventMember.fromJson(Map<String, dynamic> json) => EventMember(
    userId: (json['userId'] as num).toInt(),
    username: (json['username'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    role: (json['role'] ?? 'MEMBER').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
  );
}
