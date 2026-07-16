import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';
import '../widgets/eco_lottie.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiService,
    required this.onOpenMap,
    super.key,
  });

  final ApiService apiService;
  final VoidCallback onOpenMap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  bool _isScanning = false;

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

      setState(() => _isScanning = true);
      final result = await _geminiService.analyzeWasteImage(image);
      await widget.apiService.saveScanResult(result);

      if (!mounted) {
        return;
      }

      setState(() => _isScanning = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResultScreen(result: result, onFindBins: widget.onOpenMap),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not analyze this image. ${error.toString()}'),
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
              IconButton(
                tooltip: 'Open recycling bins',
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
                  label: const Text('Take Photo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _pickAndAnalyze(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload Gallery'),
                ),
                const SizedBox(height: 24),
                const _HowItWorksCard(),
              ],
            ),
          ),
        ),
        if (_isScanning) const _ScanningOverlay(),
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
        color: Colors.white,
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
                    label: Text('$points pts'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Scan waste. Learn its impact. Earn greener habits.',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16351D),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use your camera or gallery to classify materials and find nearby recycling bins.',
            style: textTheme.bodyLarge?.copyWith(color: Colors.black54),
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
              'Today\'s loop',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const _StepRow(
              icon: Icons.center_focus_strong_outlined,
              title: 'Capture',
              subtitle: 'Take or upload a clear photo of one item.',
            ),
            const _StepRow(
              icon: Icons.psychology_alt_outlined,
              title: 'Understand',
              subtitle: 'Gemini returns material, decay time, and reuse ideas.',
            ),
            _StepRow(
              icon: Icons.add_location_alt_outlined,
              title: 'Recycle',
              subtitle:
                  'Earn ${AppConstants.pointsPerScan} points and find a nearby bin.',
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
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

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
                  'Analyzing material',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('A cleaner answer is sprouting...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
