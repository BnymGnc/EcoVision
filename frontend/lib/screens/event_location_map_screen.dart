import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EventLocationMapScreen extends StatelessWidget {
  const EventLocationMapScreen({
    required this.title,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final String title;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik Konumu')),
      body: FlutterMap(
        options: MapOptions(initialCenter: point, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ecovision.frontend',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 64,
                height: 64,
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ],
          ),
          RichAttributionWidget(
            attributions: const [
              TextSourceAttribution('OpenStreetMap katkıda bulunanları'),
            ],
          ),
        ],
      ),
    );
  }
}
