class ScanResult {
  const ScanResult({
    required this.material,
    required this.isRecyclable,
    required this.decayYears,
    required this.recycledInto,
    required this.scannedAt,
    this.pointsAwarded = 0,
    this.detections = const [],
  });

  final String material;
  final bool isRecyclable;
  final String decayYears;
  final String recycledInto;
  final DateTime scannedAt;
  final int pointsAwarded;
  final List<WasteDetection> detections;

  factory ScanResult.fromGeminiJson(Map<String, dynamic> json) {
    final scan = json['scan'] is Map<String, dynamic>
        ? json['scan'] as Map<String, dynamic>
        : json;
    final detections = (json['detections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WasteDetection.fromJson)
        .toList(growable: false);
    final parsed = ScanResult.fromJson(scan);
    return ScanResult(
      material: parsed.material,
      isRecyclable: parsed.isRecyclable,
      decayYears: parsed.decayYears,
      recycledInto: parsed.recycledInto,
      scannedAt: parsed.scannedAt,
      pointsAwarded: parsed.pointsAwarded,
      detections: detections,
    );
  }

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

class WasteDetection {
  const WasteDetection({
    required this.type,
    required this.material,
    required this.confidence,
    required this.machineEligible,
    required this.eligibilityLabel,
  });

  final String type;
  final String material;
  final double confidence;
  final bool machineEligible;
  final String eligibilityLabel;

  factory WasteDetection.fromJson(Map<String, dynamic> json) {
    return WasteDetection(
      type: (json['type'] ?? 'DIGER').toString(),
      material: (json['material'] ?? json['type'] ?? 'Bilinmeyen').toString(),
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
      machineEligible: json['machine_eligible'] as bool? ?? false,
      eligibilityLabel: (json['eligibility_label'] ?? 'Uygun değil').toString(),
    );
  }
}
