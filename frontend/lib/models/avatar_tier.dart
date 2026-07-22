class AvatarTier {
  const AvatarTier({
    required this.level,
    required this.title,
    required this.requiredLifetimePoints,
    required this.unlocked,
    required this.equipped,
  });

  final int level;
  final String title;
  final int requiredLifetimePoints;
  final bool unlocked;
  final bool equipped;

  factory AvatarTier.fromJson(Map<String, dynamic> json) {
    return AvatarTier(
      level: (json['level'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      requiredLifetimePoints: (json['requiredLifetimePoints'] as num? ?? 0)
          .toInt(),
      unlocked: json['unlocked'] as bool? ?? false,
      equipped: json['equipped'] as bool? ?? false,
    );
  }
}
