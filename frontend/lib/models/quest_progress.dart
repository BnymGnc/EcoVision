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
    final questId = _asInt(json['questId'] ?? json['id']);
    final targetAmount = _asInt(json['targetAmount'], fallback: 1);
    final title = (json['title'] ?? '').toString().trim();
    if (questId == null || questId <= 0) {
      throw const FormatException('Görev kimliği eksik veya geçersiz.');
    }
    if (title.isEmpty || targetAmount == null || targetAmount <= 0) {
      throw const FormatException('Görev içeriği eksik veya geçersiz.');
    }
    return QuestProgress(
      questId: questId,
      progressId: _asInt(json['progressId']),
      code: (json['code'] ?? '').toString(),
      title: title,
      description: (json['description'] ?? '').toString(),
      rewardPoints: _asInt(json['rewardPoints']) ?? 0,
      targetAmount: targetAmount,
      schedule: (json['schedule'] ?? 'MILESTONE').toString(),
      domain: (json['domain'] ?? 'ECO_IMPACT').toString(),
      currentAmount: _asInt(json['currentAmount']) ?? 0,
      completed: _asBool(json['completed']),
      claimed: _asBool(json['claimed']),
      checkInAvailable: _asBool(json['checkInAvailable']),
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }
}

class QuestClaimResult {
  const QuestClaimResult({
    required this.quest,
    required this.pointsAwarded,
    required this.totalPoints,
    required this.message,
  });

  final QuestProgress quest;
  final int pointsAwarded;
  final int totalPoints;
  final String message;

  factory QuestClaimResult.fromJson(Map<String, dynamic> json) {
    final questJson = json['quest'];
    if (questJson is! Map) {
      throw const FormatException('Görev ödülü yanıtı geçersiz.');
    }
    return QuestClaimResult(
      quest: QuestProgress.fromJson(Map<String, dynamic>.from(questJson)),
      pointsAwarded: _asInt(json['pointsAwarded']) ?? 0,
      totalPoints: _asInt(json['totalPoints']) ?? 0,
      message: (json['message'] ?? '').toString(),
    );
  }
}

int? _asInt(Object? value, {int? fallback}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}
