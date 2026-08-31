import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../models/map_pin.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.apiService,
    this.requestedMaterial,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });

  final ApiService apiService;
  final String? requestedMaterial;
  final int notificationCount;
  final VoidCallback? onNotifications;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _materials = ['pet', 'glass', 'aluminum'];

  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<MapPin> _pins = [];
  Set<String> _selectedMaterials = {};
  double? _radiusKm = 10;
  bool _isLoading = true;
  bool _mapReady = false;
  bool _isAddingPin = false;

  bool get _canAddPins => widget.apiService.currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.requestedMaterial != null) {
      _selectedMaterials = {widget.requestedMaterial!};
      _radiusKm = null;
    }
    _loadMap();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestedMaterial != null &&
        widget.requestedMaterial != oldWidget.requestedMaterial) {
      _selectedMaterials = {widget.requestedMaterial!};
      _radiusKm = null;
      _loadMap();
    }
  }

  Future<void> _loadMap() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentOrFallbackLocation();
      final pins = await widget.apiService.fetchNearestMapPins(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        materials: _selectedMaterials,
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        _pins = List<MapPin>.unmodifiable(pins);
        _isLoading = false;
      });
      _moveTo(location);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _currentLocation ??= AppConstants.sanliurfaFallback;
        _isLoading = false;
      });
      _showError(error);
    }
  }

  void _moveTo(LatLng location) {
    if (!_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(location, 14);
    });
  }

  Future<void> _openFilters() async {
    var draftMaterials = Set<String>.from(_selectedMaterials);
    var draftRadius = _radiusKm;

    final result = await showEcoGlassSheet<_MapFilters>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOA Makine Filtreleri',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sana uygun ve gerçekten erişilebilir makineleri göster.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kabul edilen malzemeler',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final material in _materials)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draftMaterials.contains(material),
                    title: Text(_materialLabel(material)),
                    secondary: Icon(_materialIcon(material)),
                    onChanged: (selected) => setSheetState(() {
                      if (selected ?? false) {
                        draftMaterials.add(material);
                      } else {
                        draftMaterials.remove(material);
                      }
                    }),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Arama yarıçapı',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      draftRadius == null
                          ? 'Sınırsız'
                          : '${draftRadius!.round()} km',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draftRadius == null,
                  title: const Text('Sınırsız mesafe'),
                  subtitle: const Text(
                    'Türkiye genelindeki tüm makineleri göster',
                  ),
                  secondary: const Icon(Icons.public_rounded),
                  onChanged: (value) =>
                      setSheetState(() => draftRadius = value ? null : 10),
                ),
                if (draftRadius != null)
                  Slider(
                    value: draftRadius!,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${draftRadius!.round()} km',
                    onChanged: (value) =>
                        setSheetState(() => draftRadius = value),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() {
                        draftMaterials = {};
                        draftRadius = 10;
                      }),
                      child: const Text('Sıfırla'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          _MapFilters(
                            materials: draftMaterials,
                            radiusKm: draftRadius,
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Sonuçları Göster'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedMaterials = result.materials;
      _radiusKm = result.radiusKm;
    });
    await _loadMap();
  }

  Future<void> _showMachine(MapPin pin) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.recycling_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pin.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DetailRow(
                icon: Icons.location_on_outlined,
                title: 'Adres',
                value: pin.address.isEmpty
                    ? 'Adres bilgisi bulunmuyor'
                    : pin.address,
              ),
              const SizedBox(height: 12),
              const Text(
                'Kabul edilen malzemeler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final material in _materials)
                _MaterialAcceptance(
                  material: _materialLabel(material),
                  icon: _materialIcon(material),
                  accepted: pin.accepts(material),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _mapController.move(pin.point, 16);
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Haritada Odaklan'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDirections(pin);
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Yol Tarifi Al'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDirections(MapPin pin) async {
    final destinations = <(String, IconData, Uri)>[
      (
        'Google Maps',
        Icons.map_outlined,
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination='
          '${pin.latitude},${pin.longitude}',
        ),
      ),
      (
        'Apple Maps',
        Icons.navigation_outlined,
        Uri.parse(
          'https://maps.apple.com/?daddr=${pin.latitude},${pin.longitude}',
        ),
      ),
      (
        'Yandex Maps',
        Icons.route_outlined,
        Uri.parse(
          'https://yandex.com/maps/?rtext=~${pin.latitude},${pin.longitude}'
          '&rtt=auto',
        ),
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Navigasyon uygulaması seç',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.$2),
                title: Text(destination.$1),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () async {
                  Navigator.pop(context);
                  final opened = await launchUrl(
                    destination.$3,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && mounted) {
                    _showError('Navigasyon uygulaması açılamadı.');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOfficialPin(LatLng point) async {
    if (!_canAddPins || _isAddingPin) return;
    setState(() => _isAddingPin = true);
    try {
      final pin = await widget.apiService.addOfficialMapPin(
        title: 'Resmî Geri Dönüşüm Noktası',
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (mounted) setState(() => _pins = [pin, ..._pins]);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isAddingPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _currentLocation ?? AppConstants.sanliurfaFallback;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0),
        surfaceTintColor: colors.surface.withValues(alpha: 0),
        title: const Text('DOA Geri Dönüşüm'),
        actions: [
          if (widget.onNotifications != null)
            NotificationBell(
              count: widget.notificationCount,
              onPressed: widget.onNotifications!,
            ),
          IconButton(
            tooltip: 'Filtreler',
            onPressed: _isLoading ? null : _openFilters,
            icon: Badge(
              isLabelVisible: _selectedMaterials.isNotEmpty || _radiusKm != 10,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isLoading ? null : _loadMap,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: location,
              initialZoom: 13.5,
              minZoom: 3,
              onMapReady: () {
                _mapReady = true;
                _moveTo(location);
              },
              onLongPress: (_, point) => _addOfficialPin(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecovision.app',
              ),
              MarkerLayer(markers: _markers(location)),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap katkıda bulunanları'),
                ],
              ),
            ],
          ),
          if (_isLoading || _isAddingPin)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 4),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _MachineSummary(
              pins: _pins,
              radiusKm: _radiusKm,
              selectedMaterials: _selectedMaterials,
              onTap: _showMachine,
              onFilters: _openFilters,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _markers(LatLng userLocation) => [
    Marker(
      point: userLocation,
      width: 50,
      height: 50,
      child: _MapMarker(
        icon: Icons.person_pin_circle_rounded,
        color: Theme.of(context).colorScheme.secondary,
      ),
    ),
    for (final pin in _pins)
      Marker(
        point: pin.point,
        width: 54,
        height: 54,
        child: GestureDetector(
          onTap: () => _showMachine(pin),
          child: _MapMarker(
            icon: Icons.recycling_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
  ];

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MachineSummary extends StatelessWidget {
  const _MachineSummary({
    required this.pins,
    required this.radiusKm,
    required this.selectedMaterials,
    required this.onTap,
    required this.onFilters,
  });

  final List<MapPin> pins;
  final double? radiusKm;
  final Set<String> selectedMaterials;
  final ValueChanged<MapPin> onTap;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pins.length} DOA makinesi bulundu',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: onFilters,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    radiusKm == null ? 'Sınırsız' : '${radiusKm!.round()} km',
                  ),
                ),
              ],
            ),
            if (pins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Bu filtrelerde makine bulunamadı. Yarıçapı genişletmeyi dene.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pins.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final pin = pins[index];
                    final distanceKm = pin.distanceKm;
                    return InkWell(
                      onTap: () => onTap(pin),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.recycling_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pin.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    distanceKm == null
                                        ? 'Mesafe bilinmiyor'
                                        : distanceKm < 1
                                        ? '${(distanceKm * 1000).round()} m'
                                        : '${distanceKm.toStringAsFixed(1)} km',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _MaterialAcceptance extends StatelessWidget {
  const _MaterialAcceptance({
    required this.material,
    required this.icon,
    required this.accepted,
  });

  final String material;
  final IconData icon;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = accepted ? colors.primary : colors.error;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        material,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            accepted ? 'Kabul ediyor' : 'Kabul etmiyor',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFilters {
  const _MapFilters({required this.materials, required this.radiusKm});

  final Set<String> materials;
  final double? radiusKm;
}

IconData _materialIcon(String material) {
  final normalized = material.toLowerCase();
  if (normalized.contains('cam') || normalized.contains('glass')) {
    return Icons.wine_bar_outlined;
  }
  if (normalized.contains('alü') || normalized.contains('alum')) {
    return Icons.soup_kitchen_outlined;
  }
  return Icons.local_drink_outlined;
}

String _materialLabel(String material) {
  return switch (material.toLowerCase()) {
    'pet' => 'PET',
    'glass' => 'Cam',
    'aluminum' => 'Alüminyum',
    _ => material,
  };
}
