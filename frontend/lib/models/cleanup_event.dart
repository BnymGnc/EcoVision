class CleanupEvent {
  const CleanupEvent({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.location,
    required this.eventDate,
    this.imageUrl,
  });

  final int id;
  final int creatorId;
  final String creatorName;
  final String title;
  final String description;
  final String location;
  final DateTime eventDate;
  final String? imageUrl;

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
      creatorName: (json['creatorName'] ?? 'EcoVision User').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      eventDate:
          DateTime.tryParse((json['eventDate'] ?? '').toString()) ??
          DateTime.now(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}
