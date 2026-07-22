class GroupMission {
  const GroupMission({
    required this.id,
    required this.eventId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.unit,
  });

  final int id;
  final int eventId;
  final String title;
  final int targetAmount;
  final int currentAmount;
  final String unit;

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  factory GroupMission.fromJson(Map<String, dynamic> json) {
    return GroupMission(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      targetAmount: (json['targetAmount'] as num? ?? 0).toInt(),
      currentAmount: (json['currentAmount'] as num? ?? 0).toInt(),
      unit: (json['unit'] ?? 'items').toString(),
    );
  }
}
