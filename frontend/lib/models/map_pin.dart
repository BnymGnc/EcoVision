import 'package:latlong2/latlong.dart';

class MapPin {
  const MapPin({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    required this.address,
    required this.acceptedMaterials,
    required this.binStates,
    required this.active,
    this.distanceKm,
  });

  final int id;
  final String title;
  final double latitude;
  final double longitude;
  final String type;
  final int createdById;
  final String createdByName;
  final DateTime createdAt;
  final double? distanceKm;
  final String address;
  final Set<String> acceptedMaterials;
  final Map<String, bool> binStates;
  final bool active;

  LatLng get point => LatLng(latitude, longitude);

  bool accepts(String material) =>
      binStates[_normalizeMaterial(material)] ?? false;

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      id: _parseInt(json['id'], field: 'id'),
      title: (json['title'] ?? 'Official Recycling Bin').toString(),
      latitude: _parseDouble(json['latitude'], field: 'latitude'),
      longitude: _parseDouble(json['longitude'], field: 'longitude'),
      type: (json['type'] ?? 'OFFICIAL_RECYCLING_BIN').toString(),
      createdById: (json['createdById'] as num? ?? 0).toInt(),
      createdByName: (json['createdByName'] ?? 'EcoVision Admin').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      address: (json['address'] ?? '').toString(),
      acceptedMaterials:
          (json['acceptedMaterials'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toSet(),
      binStates: (json['binStates'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key.toLowerCase(), value == true),
      ),
      active: json['active'] as bool? ?? true,
    );
  }

  static String _normalizeMaterial(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'plastic' || normalized == 'plastik') return 'pet';
    if (normalized == 'cam') return 'glass';
    if (normalized.contains('alü') || normalized.contains('alum')) {
      return 'aluminum';
    }
    return normalized;
  }

  static double _parseDouble(Object? value, {required String field}) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Invalid $field value for map pin: $value');
    }
    return parsed;
  }

  static int _parseInt(Object? value, {required String field}) {
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null) {
      throw FormatException('Invalid $field value for map pin: $value');
    }
    return parsed;
  }
}
