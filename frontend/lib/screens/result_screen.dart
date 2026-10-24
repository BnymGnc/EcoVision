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
  String? _confirmedMaterial;
  bool? _beverage;
  bool? _doaMark;
  bool? _emptyIntact;
  double? _volume;
  String _eligibility = 'UNKNOWN';
  bool _savingAction = false;
  late final String _actionKey =
      'scan_${widget.result.scannedAt.toUtc().microsecondsSinceEpoch}';

  Future<void> _recordAction() async {
    final amount = TextEditingController();
    String material = _machineMaterial ?? 'other';
    String route = 'RECYCLING';
    final answers = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Gerçekleştirdiğin eylemi kaydet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yalnız gerçekleştirdiğin ayrıştırmayı beyan et. Tarama veya yol tarifi iade teyidi değildir.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: material,
                  decoration: const InputDecoration(labelText: 'Malzeme'),
                  items: const [
                    DropdownMenuItem(value: 'pet', child: Text('PET')),
                    DropdownMenuItem(value: 'glass', child: Text('Cam')),
                    DropdownMenuItem(
                      value: 'aluminum',
                      child: Text('Alüminyum kutu'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Diğer')),
                  ],
                  onChanged: (value) =>
                      update(() => material = value ?? 'other'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tarttığın kütle (gram)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: route,
                  decoration: const InputDecoration(
                    labelText: 'Uyguladığın yönetim yolu',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'RECYCLING',
                      child: Text('Geri dönüşüme teslim'),
                    ),
                    DropdownMenuItem(
                      value: 'LANDFILL',
                      child: Text('Karışık atık'),
                    ),
                  ],
                  onChanged: (value) =>
                      update(() => route = value ?? 'RECYCLING'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Karşılaştırma: düzenli depolama. Tahmini fark ABD WARM v13 modeline dayanır; Türkiye ölçümü değildir.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final grams = double.tryParse(amount.text.replaceAll(',', '.'));
                if (grams == null || !grams.isFinite || grams <= 0) return;
                Navigator.pop(context, <String, dynamic>{
                  'actionKey': _actionKey,
                  'material': material,
                  'massKg': grams / 1000,
                  'baseline': 'LANDFILL',
                  'selected': route,
                });
              },
              child: const Text('Beyanımı Kaydet'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
    if (answers == null || !mounted) return;
    setState(() => _savingAction = true);
    try {
      final result = await widget.apiService.saveWasteAction(answers);
      if (!mounted) return;
      final difference = result['estimatedDifferenceKg'] as num?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            difference == null
                ? 'Eylemin kaydedildi. Bu malzeme için etki hesaplanamadı.'
                : 'Beyanın kaydedildi. Tahmini fark: ${difference.toStringAsFixed(3)} kg CO₂e.',
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebration());
    _checkingBins = false;
  }

  String? get _machineMaterial {
    if (_confirmedMaterial != null) return _confirmedMaterial;
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

  Future<void> _confirmPackaging() async {
    setState(() => _checkingBins = true);
    try {
      final result = await widget.apiService.checkPackagingEligibility({
        'material': _machineMaterial,
        'singleUseNonDairyBeverage': _beverage,
        'doaMark': _doaMark,
        'emptyAndIntact': _emptyIntact,
        'volumeLitres': _volume,
      });
      if (!mounted) return;
      setState(() => _eligibility = result['eligibilityStatus'].toString());
      if (_eligibility == 'ELIGIBLE')
        await _checkCompatibleBins();
      else if (mounted)
        setState(() {
          _checkingBins = false;
          _hasCompatibleBins = false;
        });
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingBins = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
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
        _hasCompatibleBins = pins.any((pin) => pin.supports(material));
      });
      if (!_hasCompatibleBins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu malzemeyi destekleyen bir DOA makinesi bulunamadı.',
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
    if (!mounted || widget.result.pointsAwarded <= 0) {
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
                    : 'Bu tarama için puan verilmedi. Sonucu kontrol edip yeniden deneyebilirsin.',
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
            if (widget.result.inferenceMode == 'CACHE')
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('Bu görselin son analizinden alındı'),
              ),
            if (widget.result.needsConfirmation)
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Sonucu kontrol et'),
                subtitle: Text(
                  'Birden fazla nesne veya belirsiz tahmin var. Nesneleri ayrı ayrı ve iyi ışıkta yeniden tarayabilirsin.',
                ),
              ),
            if (widget.result.detections.any((d) => d.machineEligible))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambalajı kontrol et',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Malzeme tahmini tek başına depozito uygunluğu göstermez.',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final item in const [
                            ('pet', 'PET şişe'),
                            ('glass', 'Cam şişe'),
                            ('aluminum', 'Alüminyum kutu'),
                          ])
                            ChoiceChip(
                              label: Text(item.$2),
                              selected: _machineMaterial == item.$1,
                              onSelected: (_) => setState(() {
                                _confirmedMaterial = item.$1;
                                _hasCompatibleBins = false;
                              }),
                            ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        tristate: true,
                        value: _beverage,
                        title: const Text(
                          'Tek kullanımlık, süt ürünü olmayan içecek ambalajı',
                        ),
                        onChanged: (v) => setState(() {
                          _beverage = v;
                          _hasCompatibleBins = false;
                        }),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        tristate: true,
                        value: _doaMark,
                        title: const Text('Üzerinde DOA işareti var'),
                        onChanged: (v) => setState(() {
                          _doaMark = v;
                          _hasCompatibleBins = false;
                        }),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        tristate: true,
                        value: _emptyIntact,
                        title: const Text(
                          'Boş, deforme olmamış ve bütünlüğü korunmuş',
                        ),
                        onChanged: (v) => setState(() {
                          _emptyIntact = v;
                          _hasCompatibleBins = false;
                        }),
                      ),
                      TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Ambalaj hacmi (litre)',
                        ),
                        onChanged: (v) => setState(() {
                          _volume = double.tryParse(v.replaceAll(',', '.'));
                          _hasCompatibleBins = false;
                        }),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _checkingBins ? null : _confirmPackaging,
                        child: const Text('Uygunluğu kontrol et'),
                      ),
                      Text(switch (_eligibility) {
                        'ELIGIBLE' =>
                          'Beyanına göre uygun. Son kabulü iade noktası belirler.',
                        'INELIGIBLE' =>
                          'Bu ambalaj DOA koşullarını karşılamıyor.',
                        _ => 'İşaret ve ambalaj bilgilerini tamamla.',
                      }),
                    ],
                  ),
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
                            'Model skoru: %${(detection.confidence * 100).round()} · doğruluk garantisi değildir',
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
              onPressed: _savingAction ? null : _recordAction,
              icon: const Icon(Icons.task_alt),
              label: Text(
                _savingAction
                    ? 'Kaydediliyor...'
                    : 'Gerçekleştirdiğim Eylemi Kaydet',
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
