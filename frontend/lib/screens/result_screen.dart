import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/scan_result.dart';
import '../widgets/eco_lottie.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.result,
    required this.onFindBins,
    super.key,
  });

  final ScanResult result;
  final VoidCallback onFindBins;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebration());
  }

  Future<void> _showCelebration() async {
    if (!mounted) {
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
                '+${AppConstants.pointsPerScan} points',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Nice scan. Your badge progress moved up.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _openBins() {
    widget.onFindBins();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
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
                                    ? 'Recyclable'
                                    : 'Not commonly recyclable',
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
                    _ResultMetric(
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Decay time',
                      value: result.decayYears,
                    ),
                    _ResultMetric(
                      icon: Icons.auto_awesome_motion_outlined,
                      label: 'Can become',
                      value: result.recycledInto,
                    ),
                    _ResultMetric(
                      icon: Icons.stars_outlined,
                      label: 'Reward',
                      value: '+${AppConstants.pointsPerScan} EcoVision points',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openBins,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Find Recycling Bins'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan Another Item'),
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
                Text(label, style: const TextStyle(color: Colors.black54)),
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
