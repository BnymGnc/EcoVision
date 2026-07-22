class GamificationState {
  const GamificationState({
    required this.totalPoints,
    required this.carbonFootprintCompleted,
    required this.redeemedRewardKeys,
    required this.pointsAwarded,
    required this.message,
    this.badge,
  });

  final int totalPoints;
  final bool carbonFootprintCompleted;
  final Set<String> redeemedRewardKeys;
  final int pointsAwarded;
  final String? badge;
  final String message;

  bool hasReward(String key) => redeemedRewardKeys.contains(key);

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    final rewardKeys = json['redeemedRewardKeys'];
    return GamificationState(
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      carbonFootprintCompleted:
          json['carbonFootprintCompleted'] as bool? ?? false,
      redeemedRewardKeys: rewardKeys is List
          ? rewardKeys.map((item) => item.toString()).toSet()
          : <String>{},
      pointsAwarded: (json['pointsAwarded'] as num? ?? 0).toInt(),
      badge: json['badge']?.toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
