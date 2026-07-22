class ScanResult {
  const ScanResult({
    required this.material,
    required this.isRecyclable,
    required this.decayYears,
    required this.recycledInto,
    required this.scannedAt,
    this.pointsAwarded = 0,
  });

  final String material;
  final bool isRecyclable;
  final String decayYears;
  final String recycledInto;
  final DateTime scannedAt;
  final int pointsAwarded;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      material: (json['material'] ?? json['materialType'] ?? 'Unknown material')
          .toString(),
      isRecyclable: _readBool(
        json['is_recyclable'] ?? json['isRecyclable'] ?? json['recyclable'],
      ),
      decayYears: (json['decay_years'] ?? json['decayYears'] ?? 'Unknown')
          .toString(),
      recycledInto: (json['recycled_into'] ?? json['recycledInto'] ?? 'Unknown')
          .toString(),
      scannedAt: json['scannedAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now(),
      pointsAwarded:
          (json['points_awarded'] as num? ?? json['pointsAwarded'] as num? ?? 0)
              .toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material,
      'is_recyclable': isRecyclable,
      'decay_years': decayYears,
      'recycled_into': recycledInto,
      'scanned_at': scannedAt.toIso8601String(),
      'points_awarded': pointsAwarded,
    };
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }
}
