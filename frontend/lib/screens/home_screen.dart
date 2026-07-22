import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/tflite_service.dart';
import '../widgets/eco_lottie.dart';
import 'result_screen.dart';
import '../widgets/notification_bell.dart';
import 'missions_screen.dart';
import 'eco_market_screen.dart';
import 'avatar_evolution_screen.dart';
import 'education_guide_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiService,
    required this.onOpenMap,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });

  final ApiService apiService;
  final VoidCallback onOpenMap;
  final int notificationCount;
  final VoidCallback? onNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TfliteService _tfliteService = TfliteService();
  bool _isScanning = false;
  String _scanStatus = 'Cihazda analiz ediliyor...';

  @override
  void dispose() {
    _tfliteService.close();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isScanning = true;
        _scanStatus = 'Cihazda analiz ediliyor...';
      });
      final detectedClass = await _tfliteService.runModelOnImage(image.path);

      if (!mounted) {
        return;
      }

      setState(() => _scanStatus = 'Puanlar işleniyor...');
      final previousPoints = widget.apiService.pointsListenable.value;
      final result = await widget.apiService.claimScanPoints(detectedClass);
      final currentPoints = widget.apiService.pointsListenable.value;
      final earnedBadge =
          (previousPoints == 0 && currentPoints > 0) ||
          (previousPoints < 50 && currentPoints >= 50);

      if (!mounted) {
        return;
      }

      setState(() => _isScanning = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            result: result,
            onFindBins: widget.onOpenMap,
            earnedBadge: earnedBadge,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görüntü analiz edilemedi. ${error.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('EcoVision'),
            actions: [
              if (widget.onNotifications != null)
                NotificationBell(
                  count: widget.notificationCount,
                  onPressed: widget.onNotifications!,
                ),
              IconButton(
                tooltip: 'Geri dönüşüm kutularını aç',
                onPressed: widget.onOpenMap,
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroPanel(
                  pointsListenable: widget.apiService.pointsListenable,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _pickAndAnalyze(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotoğraf Çek'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _pickAndAnalyze(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeriden Seç'),
                ),
                const SizedBox(height: 24),
                _EcoCenter(apiService: widget.apiService),
                const SizedBox(height: 18),
                const _HowItWorksCard(),
              ],
            ),
          ),
        ),
        if (_isScanning) _ScanningOverlay(message: _scanStatus),
      ],
    );
  }
}

class _EcoCenter extends StatelessWidget {
  const _EcoCenter({required this.apiService});
  final ApiService apiService;
  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Görevlerim',
        Icons.flag_outlined,
        () => MissionsScreen(
          points: apiService.pointsListenable.value,
          apiService: apiService,
        ),
      ),
      (
        'Eco-Market',
        Icons.storefront_outlined,
        () => EcoMarketScreen(apiService: apiService),
      ),
      (
        'Avatar Yolu',
        Icons.account_tree_outlined,
        () => AvatarEvolutionScreen(apiService: apiService),
      ),
      (
        'Atık Rehberi',
        Icons.menu_book_outlined,
        () => const EducationGuideScreen(),
      ),
      (
        'Liderlik',
        Icons.leaderboard_outlined,
        () => LeaderboardScreen(apiService: apiService),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eco Merkezi',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 92,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => item.$3()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.pointsListenable});

  final ValueListenable<int> pointsListenable;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.eco_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: pointsListenable,
                builder: (context, points, _) {
                  return Chip(
                    avatar: const Icon(Icons.stars_rounded, size: 18),
                    label: Text('$points puan'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Atığı tara. Etkisini öğren. Doğa için puan kazan.',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kamera veya galeriyi kullanarak malzemeyi tanı ve yakındaki geri dönüşüm kutularını bul.',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bugünün Döngüsü',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const _StepRow(
              icon: Icons.center_focus_strong_outlined,
              title: 'Görüntüle',
              subtitle: 'Tek bir atığın net fotoğrafını çek veya yükle.',
            ),
            const _StepRow(
              icon: Icons.psychology_alt_outlined,
              title: 'Tanı',
              subtitle: 'Cihazdaki model atık malzemesini belirler.',
            ),
            _StepRow(
              icon: Icons.add_location_alt_outlined,
              title: 'Geri Dönüştür',
              subtitle: 'Malzemeye göre puan kazan ve yakındaki kutuyu bul.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.32),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EcoLottie(
                  url: AppConstants.loadingLottieUrl,
                  fallbackIcon: Icons.eco_outlined,
                  size: 132,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Tarama bu cihazda gizli tutuluyor.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
