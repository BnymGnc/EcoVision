class QuestProgress {
  const QuestProgress({
    required this.questId,
    required this.code,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.targetAmount,
    required this.schedule,
    required this.domain,
    required this.currentAmount,
    required this.completed,
    required this.claimed,
    required this.checkInAvailable,
    this.progressId,
    this.expiresAt,
  });

  final int questId;
  final int? progressId;
  final String code;
  final String title;
  final String description;
  final int rewardPoints;
  final int targetAmount;
  final String schedule;
  final String domain;
  final int currentAmount;
  final bool completed;
  final bool claimed;
  final bool checkInAvailable;
  final DateTime? expiresAt;

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  factory QuestProgress.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expiresAt']?.toString();
    return QuestProgress(
      questId: (json['questId'] as num).toInt(),
      progressId: (json['progressId'] as num?)?.toInt(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      rewardPoints: (json['rewardPoints'] as num? ?? 0).toInt(),
      targetAmount: (json['targetAmount'] as num? ?? 1).toInt(),
      schedule: (json['schedule'] ?? 'MILESTONE').toString(),
      domain: (json['domain'] ?? 'ECO_IMPACT').toString(),
      currentAmount: (json['currentAmount'] as num? ?? 0).toInt(),
      completed: json['completed'] as bool? ?? false,
      claimed: json['claimed'] as bool? ?? false,
      checkInAvailable: json['checkInAvailable'] as bool? ?? false,
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }
}
