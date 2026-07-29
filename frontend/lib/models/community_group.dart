import '../core/media_url.dart';

class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.name,
    required this.description,
    required this.city,
    required this.district,
    required this.memberLimit,
    required this.memberCount,
    required this.privateGroup,
    required this.createdAt,
    this.neighborhood = '',
    this.coverImageUrl,
    this.currentUserRole,
    this.pinnedMessageId,
    this.pinnedMessageText,
    this.pinnedEventId,
    this.joinRequestStatus,
    this.inviteCode,
  });

  final int id;
  final int creatorId;
  final String creatorName;
  final String name;
  final String description;
  final String city;
  final String district;
  final String neighborhood;
  final String? coverImageUrl;
  final int memberLimit;
  final int memberCount;
  final bool privateGroup;
  final String? currentUserRole;
  final int? pinnedMessageId;
  final String? pinnedMessageText;
  final int? pinnedEventId;
  final String? joinRequestStatus;
  final String? inviteCode;
  final DateTime createdAt;

  bool get isJoined => currentUserRole != null;
  bool get hasPendingJoinRequest => joinRequestStatus == 'PENDING';
  bool get isFounder => currentUserRole == 'FOUNDER';
  bool get isAdmin =>
      isFounder ||
      currentUserRole == 'ADMIN' ||
      currentUserRole == 'GROUP_ADMIN';
  String get locationLabel => neighborhood.trim().isEmpty
      ? '$district / $city'
      : '$neighborhood, $district / $city';

  factory CommunityGroup.fromJson(Map<String, dynamic> json) {
    return CommunityGroup(
      id: (json['id'] as num).toInt(),
      creatorId: (json['creatorId'] as num? ?? 0).toInt(),
      creatorName: (json['creatorName'] ?? 'EcoVision Kullanıcısı').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      neighborhood: (json['neighborhood'] ?? '').toString(),
      coverImageUrl: MediaUrl.resolve(json['coverImageUrl']),
      memberLimit: (json['memberLimit'] as num? ?? 20).toInt(),
      memberCount: (json['memberCount'] as num? ?? 0).toInt(),
      privateGroup: json['privateGroup'] as bool? ?? false,
      currentUserRole: json['currentUserRole']?.toString(),
      pinnedMessageId: (json['pinnedMessageId'] as num?)?.toInt(),
      pinnedMessageText: json['pinnedMessageText']?.toString(),
      pinnedEventId: (json['pinnedEventId'] as num?)?.toInt(),
      joinRequestStatus: json['joinRequestStatus']?.toString(),
      inviteCode: json['inviteCode']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class GroupEvent {
  const GroupEvent({
    required this.id,
    required this.groupId,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.city,
    required this.district,
    required this.exactAddress,
    required this.attendeeCount,
    required this.capacity,
    required this.attendees,
    this.coverImageUrl,
    this.currentUserAttendance,
    this.createdAt,
  });

  final int id;
  final int groupId;
  final int creatorId;
  final String creatorName;
  final String title;
  final String description;
  final DateTime eventDate;
  final String city;
  final String district;
  final String exactAddress;
  final String? coverImageUrl;
  final int attendeeCount;
  final int capacity;
  final List<GroupEventAttendee> attendees;
  final String? currentUserAttendance;
  final DateTime? createdAt;

  bool get isAttending => currentUserAttendance == 'ATTENDING';
  bool get isFull => attendeeCount >= capacity;

  String get dateLabel {
    final local = eventDate.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}.${local.month}.${local.year}  $hour:$minute';
  }

  factory GroupEvent.fromJson(Map<String, dynamic> json) {
    return GroupEvent(
      id: (json['id'] as num).toInt(),
      groupId: (json['groupId'] as num).toInt(),
      creatorId: (json['creatorId'] as num? ?? 0).toInt(),
      creatorName: (json['creatorName'] ?? 'EcoVision Kullanıcısı').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      eventDate:
          DateTime.tryParse((json['eventDate'] ?? '').toString()) ??
          DateTime.now(),
      city: (json['city'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      exactAddress: (json['exactAddress'] ?? '').toString(),
      coverImageUrl: MediaUrl.resolve(json['coverImageUrl']),
      attendeeCount: (json['attendeeCount'] as num? ?? 0).toInt(),
      capacity: (json['capacity'] as num? ?? 20).toInt(),
      attendees: (json['attendees'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GroupEventAttendee.fromJson)
          .toList(),
      currentUserAttendance: json['currentUserAttendance']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class GroupEventAttendee {
  const GroupEventAttendee({
    required this.userId,
    required this.fullName,
    this.profilePictureUrl,
  });

  final int userId;
  final String fullName;
  final String? profilePictureUrl;

  factory GroupEventAttendee.fromJson(Map<String, dynamic> json) {
    return GroupEventAttendee(
      userId: (json['userId'] as num? ?? 0).toInt(),
      fullName: (json['fullName'] ?? 'EcoVision kullanıcısı').toString(),
      profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
    );
  }
}
