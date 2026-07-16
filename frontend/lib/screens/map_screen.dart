import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/map_pin.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final Distance _distance = const Distance();

  LatLng? _currentLocation;
  List<MapPin> _officialPins = [];
  bool _isLoading = true;
  bool _isAddingPin = false;

  bool get _canAddPins => widget.apiService.currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentOrFallbackLocation();
      final pins = await widget.apiService.fetchMapPins();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentLocation = location;
        _officialPins = pins;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentLocation ??= AppConstants.sanliurfaFallback;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addOfficialPin(LatLng point) async {
    if (!_canAddPins || _isAddingPin) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Add Official Recycling Bin'),
        content: Text(
          'Create a verified bin at ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add Bin'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isAddingPin = true);
    try {
      final pin = await widget.apiService.addOfficialMapPin(
        title: 'Official Recycling Bin',
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _officialPins = [pin, ..._officialPins];
        _isAddingPin = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _isAddingPin = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _currentLocation ?? AppConstants.sanliurfaFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycling Bins'),
        actions: [
          IconButton(
            tooltip: 'Refresh pins',
            onPressed: _isLoading ? null : _loadMap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: location,
                      initialZoom: 14.6,
                      minZoom: 3,
                      onLongPress: (_, point) => _addOfficialPin(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ecovision.app',
                      ),
                      MarkerLayer(markers: _buildMarkers(location)),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  if (_isLoading || _isAddingPin)
                    const LinearProgressIndicator(minHeight: 3),
                ],
              ),
            ),
            _PinList(
              pins: _officialPins,
              currentLocation: location,
              distance: _distance,
              canAddPins: _canAddPins,
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(LatLng userLocation) {
    return [
      Marker(
        point: userLocation,
        width: 54,
        height: 54,
        child: const _MapMarker(
          icon: Icons.person_pin_circle,
          color: Color(0xFF1565C0),
        ),
      ),
      for (final pin in _officialPins)
        Marker(
          point: pin.point,
          width: 54,
          height: 54,
          child: const _MapMarker(
            icon: Icons.recycling_rounded,
            color: Color(0xFF2E7D32),
          ),
        ),
    ];
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _PinList extends StatelessWidget {
  const _PinList({
    required this.pins,
    required this.currentLocation,
    required this.distance,
    required this.canAddPins,
  });

  final List<MapPin> pins;
  final LatLng currentLocation;
  final Distance distance;
  final bool canAddPins;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Official recycling bins',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            canAddPins
                ? 'Long-press the map to add a verified bin.'
                : 'Verified locations added by EcoVision admins.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (pins.isEmpty)
            const Text('No official bins have been added yet.')
          else
            for (final pin in pins.take(3))
              _PinTile(
                pin: pin,
                distanceMeters: distance(currentLocation, pin.point).round(),
              ),
        ],
      ),
    );
  }
}

class _PinTile extends StatelessWidget {
  const _PinTile({required this.pin, required this.distanceMeters});

  final MapPin pin;
  final int distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.recycling_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Added by ${pin.createdByName}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Text('${distanceMeters}m'),
        ],
      ),
    );
  }
}
