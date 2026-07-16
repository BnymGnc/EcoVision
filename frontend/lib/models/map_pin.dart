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
  });

  final int id;
  final String title;
  final double latitude;
  final double longitude;
  final String type;
  final int createdById;
  final String createdByName;
  final DateTime createdAt;

  LatLng get point => LatLng(latitude, longitude);

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? 'Official Recycling Bin').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: (json['type'] ?? 'OFFICIAL_RECYCLING_BIN').toString(),
      createdById: (json['createdById'] as num? ?? 0).toInt(),
      createdByName: (json['createdByName'] ?? 'EcoVision Admin').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
