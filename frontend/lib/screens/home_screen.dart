import 'package:flutter/foundation.dart' show ValueListenable;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import 'result_screen.dart';
import '../widgets/notification_bell.dart';
import 'missions_screen.dart';
import 'eco_market_screen.dart';
import 'avatar_evolution_screen.dart';
import 'education_guide_screen.dart';
import 'leaderboard_screen.dart';
import 'carbon_footprint_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiService,
    required this.onOpenMap,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });

  final ApiService apiService;
  final ValueChanged<String?> onOpenMap;
  final int notificationCount;
  final VoidCallback? onNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isScanning = false;
  String _scanStatus = 'Yapay zeka analiz ediyor...';
  OverlayEntry? _scanOverlay;

  void _hideScanOverlay() {
    _scanOverlay?.remove();
    _scanOverlay?.dispose();
    _scanOverlay = null;
  }

  @override
  void dispose() {
    _hideScanOverlay();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    if (_isScanning) return;
    try {
      await EcoHaptics.light();
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 72,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _isScanning = true;
        _scanStatus = 'Fotoğraf güvenli biçimde yükleniyor...';
      });
      _scanOverlay = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: BlockSemantics(
            child: AbsorbPointer(child: ScanningOverlay(message: _scanStatus)),
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_scanOverlay!);
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const ApiException(
          'Fotoğraf 5 MB sınırını aşıyor. Daha küçük bir fotoğraf seçin.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() => _scanStatus = 'Yapay zeka atığı tanıyor...');
      _scanOverlay?.markNeedsBuild();
      final previousPoints = widget.apiService.pointsListenable.value;
      final result = await widget.apiService.analyzeWasteImage(
        bytes: bytes,
        fileName: image.name,
      );
      final currentPoints = widget.apiService.pointsListenable.value;
      final earnedBadge =
          (previousPoints == 0 && currentPoints > 0) ||
          (previousPoints < 50 && currentPoints >= 50);

      if (!mounted) {
        return;
      }

      await EcoHaptics.heavy();
      if (!mounted) return;
      _hideScanOverlay();
      setState(() => _isScanning = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            result: result,
            apiService: widget.apiService,
            onFindBins: widget.onOpenMap,
            earnedBadge: earnedBadge,
          ),
        ),
      );
    } catch (error) {
      _hideScanOverlay();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      _hideScanOverlay();
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isScanning,
      child: Scaffold(
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
              onPressed: () {
                EcoHaptics.light();
                widget.onOpenMap(null);
              },
              icon: const Icon(Icons.map_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeroPanel(pointsListenable: widget.apiService.pointsListenable),
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
              const SizedBox(height: 8),
              Text(
                'Fotoğrafın sunucuda analiz edilir; bulut modunda Gemini’ye iletilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              _EcoCenter(apiService: widget.apiService),
              const SizedBox(height: 18),
              const _HowItWorksCard(),
            ],
          ),
        ),
      ),
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
        () => EducationGuideScreen(apiService: apiService),
      ),
      (
        'Liderlik',
        Icons.leaderboard_outlined,
        () => LeaderboardScreen(apiService: apiService),
      ),
      (
        'Karbon Ayak İzi',
        Icons.co2_rounded,
        () => CarbonFootprintScreen(apiService: apiService),
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
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  EcoHaptics.light();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => item.$3()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(16),
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
              subtitle: 'Görsel model atığın malzemesini tahmin eder.',
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

class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({required this.message, super.key});

  final String message;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    return Material(
      key: const ValueKey('scanner-surface'),
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'EcoVision AI Tarayıcı',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fotoğraf güvenli biçimde analiz ediliyor',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RepaintBoundary(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ScannerFramePainter(color: accent),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  key: const ValueKey('scanner-sweep'),
                                  painter: _ScannerSweepPainter(
                                    color: accent,
                                    progress: _controller,
                                  ),
                                ),
                              ),
                              Center(
                                child: Icon(
                                  Icons.recycling_rounded,
                                  color: colors.primary.withValues(alpha: 0.28),
                                  size: math.min(
                                    84,
                                    math.min(
                                          constraints.maxWidth,
                                          constraints.maxHeight,
                                        ) *
                                        0.32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerSweepPainter extends CustomPainter {
  _ScannerSweepPainter({required this.color, required this.progress})
    : super(repaint: progress);
  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final inset = math.min(20.0, size.shortestSide * 0.12);
    final y = inset + progress.value * math.max(0, size.height - 2 * inset);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset(inset, y),
      Offset(size.width - inset, y),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawLine(
      Offset(inset, y),
      Offset(size.width - inset, y),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScannerSweepPainter oldDelegate) =>
      color != oldDelegate.color || progress != oldDelegate.progress;
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final length = math.min(36.0, size.shortestSide * 0.22);
    final paths = <Path>[
      Path()
        ..moveTo(0, length)
        ..lineTo(0, 0)
        ..lineTo(length, 0),
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, length),
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - length, size.height),
      Path()
        ..moveTo(length, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - length),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
