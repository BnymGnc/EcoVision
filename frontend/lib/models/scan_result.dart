class ScanResult {
  const ScanResult({
    required this.material,
    required this.isRecyclable,
    required this.decayYears,
    required this.recycledInto,
    required this.scannedAt,
  });

  final String material;
  final bool isRecyclable;
  final String decayYears;
  final String recycledInto;
  final DateTime scannedAt;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      material: (json['material'] ?? json['materialType'] ?? 'Unknown material')
          .toString(),
      isRecyclable: _readBool(json['is_recyclable'] ?? json['recyclable']),
      decayYears: (json['decay_years'] ?? 'Unknown').toString(),
      recycledInto: (json['recycled_into'] ?? 'Unknown').toString(),
      scannedAt: json['scannedAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material,
      'is_recyclable': isRecyclable,
      'decay_years': decayYears,
      'recycled_into': recycledInto,
      'scanned_at': scannedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toBackendJson() {
    return {'materialType': material, 'recyclable': isRecyclable};
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
