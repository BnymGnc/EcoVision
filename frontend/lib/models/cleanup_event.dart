class CleanupEvent {
  const CleanupEvent({
    required this.id,
    required this.creatorId,
    required this.adminId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.location,
    required this.eventDate,
    this.city = '',
    this.district = '',
    this.neighborhood = '',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.memberLimit = 20,
    this.memberCount = 0,
    this.privateGroup = false,
    this.currentUserRole,
    this.eventTime = '',
    this.exactAddress = '',
    this.coverImageUrl,
    this.attendeeCount = 0,
    this.currentUserAttendance,
  });

  final int id;
  final int creatorId;
  final int adminId;
  final String creatorName;
  final String title;
  final String description;
  final String location;
  final DateTime eventDate;
  final String city;
  final String district;
  final String neighborhood;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final int memberLimit;
  final int memberCount;
  final bool privateGroup;
  final String? currentUserRole;
  final String eventTime;
  final String exactAddress;
  final String? coverImageUrl;
  final int attendeeCount;
  final String? currentUserAttendance;

  bool get isJoined => currentUserRole != null;
  bool get isAdmin => currentUserRole == 'GROUP_ADMIN';
  bool get isAttending => currentUserAttendance == 'ATTENDING';

  String get dateLabel {
    final local = eventDate.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }

  factory CleanupEvent.fromJson(Map<String, dynamic> json) {
    return CleanupEvent(
      id: (json['id'] as num).toInt(),
      creatorId: (json['creatorId'] as num? ?? 0).toInt(),
      adminId: (json['adminId'] as num? ?? json['creatorId'] as num? ?? 0)
          .toInt(),
      creatorName: (json['creatorName'] ?? 'EcoVision Kullanıcısı').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      eventDate:
          DateTime.tryParse((json['eventDate'] ?? '').toString()) ??
          DateTime.now(),
      city: (json['city'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      neighborhood: (json['neighborhood'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      memberLimit: (json['memberLimit'] as num? ?? 20).toInt(),
      memberCount: (json['memberCount'] as num? ?? 0).toInt(),
      privateGroup: json['privateGroup'] as bool? ?? false,
      currentUserRole: json['currentUserRole']?.toString(),
      eventTime: (json['eventTime'] ?? '').toString(),
      exactAddress: (json['exactAddress'] ?? '').toString(),
      coverImageUrl:
          (json['coverImageUrl'] ?? json['imageUrl'])?.toString(),
      attendeeCount: (json['attendeeCount'] as num? ?? 0).toInt(),
      currentUserAttendance: json['currentUserAttendance']?.toString(),
    );
  }
}
