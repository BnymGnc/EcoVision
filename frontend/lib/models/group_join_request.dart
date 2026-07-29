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

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) =>
      GroupJoinRequest(
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
      );
}
