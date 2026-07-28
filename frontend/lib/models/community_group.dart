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
  final DateTime createdAt;

  bool get isJoined => currentUserRole != null;
  bool get isAdmin => currentUserRole == 'GROUP_ADMIN';
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
      coverImageUrl: json['coverImageUrl']?.toString(),
      memberLimit: (json['memberLimit'] as num? ?? 20).toInt(),
      memberCount: (json['memberCount'] as num? ?? 0).toInt(),
      privateGroup: json['privateGroup'] as bool? ?? false,
      currentUserRole: json['currentUserRole']?.toString(),
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
    this.coverImageUrl,
    this.currentUserAttendance,
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
  final String? currentUserAttendance;

  bool get isAttending => currentUserAttendance == 'ATTENDING';

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
      coverImageUrl: json['coverImageUrl']?.toString(),
      attendeeCount: (json['attendeeCount'] as num? ?? 0).toInt(),
      currentUserAttendance: json['currentUserAttendance']?.toString(),
    );
  }
}
