import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../services/academy_repository.dart';
import '../services/share_service.dart';
import '../widgets/eco_lottie.dart';
import '../widgets/mascot_celebration.dart';
import 'education_detail_screen.dart';
import 'education_guide_screen.dart';

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
  bool _openingGuide = false;

  Future<void> _openGuide() async {
    if (_openingGuide) return;
    setState(() => _openingGuide = true);
    try {
      final modules = await const AcademyRepository().loadModules();
      final type = widget.result.detections.isEmpty
          ? widget.result.material.toUpperCase()
          : widget.result.detections.first.type.toUpperCase();
      final category = switch (type) {
        'PET' || 'PLASTIK' || 'PLASTIC' => 'modul-1',
        'CAM' || 'GLASS' => 'modul-2',
        'KAGIT' || 'PAPER' || 'CARDBOARD' => 'modul-3',
        'METAL' || 'ALUMINUM' || 'ALUMINIUM' => 'modul-4',
        'ELEKTRONIK' || 'ELECTRONICS' => 'modul-5',
        'KOMPOZIT' => 'modul-6',
        'YAG' || 'OIL' => 'modul-7',
        'TEKSTIL' => 'modul-8',
        'ORGANIK' || 'ORGANIC' => 'modul-9',
        'TIBBI' || 'MEDICAL' => 'modul-10',
        _ => null,
      };
      // Reading remains available even when the progress request is offline.
      var completed = <String>{};
      try {
        completed = await widget.apiService.fetchEducationProgress().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {}
      if (!mounted) return;
      final matching = modules.where((module) => module.categoryId == category);
      await Navigator.of(context).push(
        MaterialPageRoute<String>(
          builder: (_) => matching.isEmpty
              ? WasteGuideScreen(
                  apiService: widget.apiService,
                  modules: modules,
                )
              : EducationDetailScreen(
                  module: matching.first,
                  apiService: widget.apiService,
                  alreadyCompleted: completed.contains(category),
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atık rehberi açılamadı. Lütfen tekrar dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingGuide = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebration());
  }

  String? get _machineMaterial {
    for (final detection in widget.result.detections) {
      final material = switch (detection.type.toUpperCase()) {
        'PET' => 'pet',
        'CAM' || 'GLASS' => 'glass',
        'ALUMINUM' || 'ALUMINIUM' => 'aluminum',
        _ => null,
      };
      if (material != null) return material;
    }
    final material = widget.result.material.toLowerCase();
    if (material.contains('pet')) return 'pet';
    if (material.contains('cam') || material.contains('glass')) return 'glass';
    if (material.contains('alüminyum') || material.contains('aluminum')) {
      return 'aluminum';
    }
    // Generic plastic/metal is not proof of PET/aluminium. The map still
    // opens without a material filter rather than hiding its entry button.
    return null;
  }

  Future<void> _showCelebration() async {
    if (!mounted || widget.result.pointsAwarded <= 0) return;
    if (widget.earnedBadge) {
      await MascotCelebration.show(
        context,
        detail: 'Yeni rozetin açıldı ve profilindeki yerini aldı.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
              '+${widget.result.pointsAwarded} puan',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Harika tarama! Rozet ilerlemen yükseldi.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void _openBins() {
    widget.onFindBins(_machineMaterial);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final colors = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarama Sonucu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (result.rewardStatus == 'DUPLICATE_IMAGE')
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Bu fotoğraf için bugün puan kazandın'),
                subtitle: Text(
                  'Aynı fotoğraf bir günde tekrar puan kazandırmaz. Analizi ve haritayı kullanabilirsin.',
                ),
              ),
            if (result.inferenceMode == 'CACHE')
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('Bu görselin son analizinden alındı'),
              ),
            if (result.provider.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Icon(Icons.psychology_outlined, color: colors.primary),
                title: const Text('Yapay zeka analizi'),
                subtitle: Text(
                  result.provider == 'ONNX_CPU'
                      ? 'Yerel model · Sunucuda görüntü sınıflandırma'
                      : result.provider == 'GEMINI'
                      ? 'Gemini · Bulutta görüntü analizi'
                      : 'Görsel malzeme tahmini',
                ),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      result.provider == 'ONNX_CPU'
                          ? 'Model, fotoğrafı plastik, cam, metal, kağıt, karton ve diğer sınıfları arasında değerlendirir. PET türünü, depozito işaretini veya gerçekleşmiş geri dönüşümü doğrulamaz.'
                          : 'Yapay zeka fotoğraftaki malzemeleri tahmin eder. Barkod, depozito kapsamı veya makinenin kesin kabulü yalnızca fotoğrafla doğrulanamaz.',
                      style: texts.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                  if (result.modelVersion.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Model: ${result.modelVersion}',
                          style: texts.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            if (result.needsConfirmation)
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Sonucu kontrol et'),
                subtitle: Text(
                  'Belirsiz tahminde atığı iyi ışıkta tek başına yeniden tarayabilirsin.',
                ),
              ),
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
                                ? colors.primaryContainer
                                : colors.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            result.isRecyclable
                                ? Icons.recycling_rounded
                                : Icons.delete_outline,
                            color: result.isRecyclable
                                ? colors.onPrimaryContainer
                                : colors.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.material,
                                style: texts.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.isRecyclable
                                    ? 'Geri dönüştürülebilir'
                                    : 'Genellikle geri dönüştürülemez',
                                style: TextStyle(
                                  color: result.isRecyclable
                                      ? colors.primary
                                      : colors.error,
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
                        style: texts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final detection in result.detections)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.science_outlined,
                            color: colors.primary,
                          ),
                          title: Text(detection.material),
                          subtitle: Text(
                            'Model skoru: %${(detection.confidence * 100).round()} · doğruluk garantisi değildir',
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
            FilledButton.icon(
              onPressed: _openBins,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('DOA Makinelerini Haritada Göster'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openingGuide ? null : _openGuide,
              icon: Icon(
                _openingGuide
                    ? Icons.hourglass_top_rounded
                    : Icons.menu_book_outlined,
              ),
              label: Text(
                _openingGuide
                    ? 'Rehber açılıyor...'
                    : 'Bu Atığın Ayırma Rehberi',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: EcoShareService.shareEcoUpgrade,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Eko İlerlememi Paylaş'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
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
  Widget build(BuildContext context) => Padding(
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
