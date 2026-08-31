import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/share_service.dart';
import '../widgets/eco_lottie.dart';
import '../widgets/mascot_celebration.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.result,
    required this.apiService,
    required this.onFindBins,
    this.earnedBadge = false,
    super.key,
  });

  final ScanResult result;
  final ApiService apiService;
  final ValueChanged<String?> onFindBins;
  final bool earnedBadge;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final LocationService _locationService = LocationService();
  bool _checkingBins = true;
  bool _hasCompatibleBins = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebration());
    _checkCompatibleBins();
  }

  String? get _machineMaterial {
    for (final detection in widget.result.detections) {
      if (!detection.machineEligible) continue;
      return switch (detection.type.toUpperCase()) {
        'PET' => 'pet',
        'CAM' => 'glass',
        'ALUMINUM' => 'aluminum',
        _ => null,
      };
    }
    return null;
  }

  Future<void> _checkCompatibleBins() async {
    final material = _machineMaterial;
    if (material == null) {
      if (mounted) setState(() => _checkingBins = false);
      return;
    }
    try {
      final location = await _locationService.getCurrentOrFallbackLocation();
      final pins = await widget.apiService.fetchNearestMapPins(
        latitude: location.latitude,
        longitude: location.longitude,
        limit: 1,
        materials: {material},
      );
      if (!mounted) return;
      setState(() {
        _checkingBins = false;
        _hasCompatibleBins = pins.any((pin) => pin.accepts(material));
      });
      if (!_hasCompatibleBins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu malzemeyi aktif kabul eden bir DOA makinesi bulunamadı.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _checkingBins = false);
    }
  }

  Future<void> _showCelebration() async {
    if (!mounted) {
      return;
    }

    if (widget.earnedBadge) {
      await MascotCelebration.show(
        context,
        detail: 'Yeni rozetin açıldı ve profilindeki yerini aldı.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EcoLottie(
                url: AppConstants.celebrationLottieUrl,
                fallbackIcon: Icons.workspace_premium_outlined,
                size: 160,
                repeat: false,
              ),
              Text(
                widget.result.pointsAwarded > 0
                    ? '+${widget.result.pointsAwarded} points'
                    : 'Sınıflandırma kaydedildi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.result.pointsAwarded > 0
                    ? 'Harika tarama! Rozet ilerlemen yükseldi.'
                    : 'Tanınmayan malzeme için puan verilmedi.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Devam Et'),
            ),
          ],
        );
      },
    );
  }

  void _openBins() {
    widget.onFindBins(_machineMaterial);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tarama Sonucu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: result.isRecyclable
                                ? colorScheme.primaryContainer
                                : colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            result.isRecyclable
                                ? Icons.recycling_rounded
                                : Icons.delete_outline,
                            color: result.isRecyclable
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.material,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.isRecyclable
                                    ? 'Geri dönüştürülebilir'
                                    : 'Genellikle geri dönüştürülemez',
                                style: TextStyle(
                                  color: result.isRecyclable
                                      ? colorScheme.primary
                                      : colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (result.detections.isNotEmpty) ...[
                      Text(
                        'Fotoğrafta bulunan atıklar',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      for (final detection in result.detections)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            detection.machineEligible
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: detection.machineEligible
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          title: Text(detection.material),
                          subtitle: Text(
                            'Güven: %${(detection.confidence * 100).round()}',
                          ),
                          trailing: Text(
                            detection.eligibilityLabel,
                            style: TextStyle(
                              color: detection.machineEligible
                                  ? colorScheme.primary
                                  : colorScheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const Divider(height: 28),
                    ],
                    _ResultMetric(
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Doğada çözünme süresi',
                      value: result.decayYears,
                    ),
                    _ResultMetric(
                      icon: Icons.auto_awesome_motion_outlined,
                      label: 'Dönüşebileceği ürün',
                      value: result.recycledInto,
                    ),
                    _ResultMetric(
                      icon: Icons.stars_outlined,
                      label: 'Ödül',
                      value: '+${result.pointsAwarded} EcoVision puanı',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_checkingBins)
              const LinearProgressIndicator(minHeight: 3)
            else if (_hasCompatibleBins)
              FilledButton.icon(
                onPressed: _openBins,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Uygun DOA Makinesini Haritada Göster'),
              ),
            if (_checkingBins || _hasCompatibleBins) const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: EcoShareService.shareEcoUpgrade,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Eko İlerlememi Paylaş'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Başka Bir Atık Tara'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
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
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
