import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/map_pin.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/notification_bell.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.apiService,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });

  final ApiService apiService;
  final int notificationCount;
  final VoidCallback? onNotifications;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final Distance _distance = const Distance();
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  List<MapPin> _officialPins = [];
  bool _isLoading = true;
  bool _isAddingPin = false;
  bool _mapReady = false;
  double? _radiusKm = 5;
  int? _limit = 5;

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
      final pins = await widget.apiService.fetchNearestMapPins(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        limit: _limit,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentLocation = location;
        _officialPins = pins;
        _isLoading = false;
      });
      _moveMapTo(location);
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

  void _moveMapTo(LatLng location) {
    if (!_mapReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(location, 15);
      }
    });
  }

  Future<void> _addOfficialPin(LatLng point) async {
    if (!_canAddPins || _isAddingPin) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Resmî Geri Dönüşüm Kutusu Ekle'),
        content: Text(
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)} konumuna doğrulanmış kutu eklensin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kutu Ekle'),
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
        title: 'Resmî Geri Dönüşüm Kutusu',
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

  Future<void> _openFilterSheet() async {
    final selected =
        await showModalBottomSheet<({double? radiusKm, int? limit})>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            double? tempRadius = _radiusKm;
            int? tempLimit = _limit;

            return StatefulBuilder(
              builder: (context, setModalState) {
                ChoiceChip radiusChip(String label, double? value) {
                  return ChoiceChip(
                    label: Text(label),
                    selected: tempRadius == value,
                    onSelected: (_) => setModalState(() => tempRadius = value),
                  );
                }

                ChoiceChip limitChip(String label, int? value) {
                  return ChoiceChip(
                    label: Text(label),
                    selected: tempLimit == value,
                    onSelected: (_) => setModalState(() => tempLimit = value),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'En Yakın Kutu Filtreleri',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Yarıçap'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          radiusChip('1 km', 1),
                          radiusChip('5 km', 5),
                          radiusChip('Sınırsız', null),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Sınır'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          limitChip('3', 3),
                          limitChip('5', 5),
                          limitChip('Sınırsız', null),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop((radiusKm: tempRadius, limit: tempLimit)),
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Filtreleri Uygula'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _radiusKm = selected.radiusKm;
      _limit = selected.limit;
    });
    await _loadMap();
  }

  String get _radiusLabel =>
      _radiusKm == null ? 'Tüm uzaklıklar' : '${_radiusKm!.round()} km';

  String get _limitLabel => _limit == null ? 'Tüm kutular' : 'İlk $_limit';

  @override
  Widget build(BuildContext context) {
    final location = _currentLocation ?? AppConstants.sanliurfaFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geri Dönüşüm Kutuları'),
        actions: [
          if (widget.onNotifications != null)
            NotificationBell(
              count: widget.notificationCount,
              onPressed: widget.onNotifications!,
            ),
          IconButton(
            tooltip: 'En yakın kutuları filtrele',
            onPressed: _isLoading ? null : _openFilterSheet,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          IconButton(
            tooltip: 'Konumları yenile',
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
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: location,
                      initialZoom: 14.6,
                      minZoom: 3,
                      onMapReady: () {
                        _mapReady = true;
                        _moveMapTo(location);
                      },
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
                          TextSourceAttribution(
                            'OpenStreetMap katkıda bulunanları',
                          ),
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
              radiusLabel: _radiusLabel,
              limitLabel: _limitLabel,
              onFilter: _openFilterSheet,
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
          child: _MapMarker(
            icon: pin.type.contains('WASTE_BASKET')
                ? Icons.delete_outline
                : Icons.recycling_rounded,
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
    required this.radiusLabel,
    required this.limitLabel,
    required this.onFilter,
  });

  final List<MapPin> pins;
  final LatLng currentLocation;
  final Distance distance;
  final bool canAddPins;
  final String radiusLabel;
  final String limitLabel;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'En Yakın Geri Dönüşüm Kutuları',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            canAddPins
                ? 'Doğrulanmış kutu eklemek için haritaya basılı tut.'
                : 'EcoVision yöneticilerinin doğruladığı konumlar.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.near_me_outlined, size: 18),
                label: Text(radiusLabel),
              ),
              Chip(
                avatar: const Icon(Icons.format_list_numbered, size: 18),
                label: Text(limitLabel),
              ),
              ActionChip(
                avatar: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Filtreler'),
                onPressed: onFilter,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pins.isEmpty)
            const Text('Bu filtrelere uygun resmî kutu bulunamadı.')
          else
            for (final pin in pins)
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
                  '${pin.createdByName} tarafından eklendi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(_distanceLabel),
        ],
      ),
    );
  }

  String get _distanceLabel {
    if (pin.distanceKm != null) {
      return '${pin.distanceKm!.toStringAsFixed(1)}km';
    }
    return distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)}km'
        : '${distanceMeters}m';
  }
}
