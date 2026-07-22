class EventMember {
  const EventMember({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.avatarLevel,
    this.profilePictureUrl,
  });

  final int userId;
  final String fullName;
  final String role;
  final int avatarLevel;
  final String? profilePictureUrl;

  bool get isAdmin => role == 'ADMIN';

  factory EventMember.fromJson(Map<String, dynamic> json) => EventMember(
    userId: (json['userId'] as num).toInt(),
    fullName: (json['fullName'] ?? '').toString(),
    role: (json['role'] ?? 'MEMBER').toString(),
    avatarLevel: (json['avatarLevel'] as num? ?? 1).toInt(),
    profilePictureUrl: json['profilePictureUrl']?.toString(),
  );
}
