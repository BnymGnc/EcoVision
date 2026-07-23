import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/carbon_footprint.dart';
import '../models/gamification_state.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class CarbonFootprintScreen extends StatefulWidget {
  const CarbonFootprintScreen({
    required this.apiService,
    this.calculationDuration = const Duration(seconds: 3),
    super.key,
  });

  final ApiService apiService;
  final Duration calculationDuration;

  @override
  State<CarbonFootprintScreen> createState() => _CarbonFootprintScreenState();
}

enum _CarbonStage { survey, calculating, result }

class _CarbonFootprintScreenState extends State<CarbonFootprintScreen> {
  final PageController _pageController = PageController();
  final Map<int, int> _selectedOptions = {};

  int _currentPage = 0;
  _CarbonStage _stage = _CarbonStage.survey;
  CarbonFootprintResult? _footprint;
  GamificationState? _reward;
  Object? _syncError;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final question = carbonQuestions[_currentPage];
    if (!_selectedOptions.containsKey(question.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devam etmek için bir yanıt seç.')),
      );
      return;
    }
    unawaited(EcoHaptics.light());
    if (_currentPage < carbonQuestions.length - 1) {
      setState(() => _currentPage++);
      await _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
      return;
    }
    await _calculate();
  }

  Future<void> _calculate() async {
    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: _selectedOptions,
    );
    setState(() {
      _footprint = result;
      _stage = _CarbonStage.calculating;
      _syncError = null;
    });

    final minimumRevealDelay = Future<void>.delayed(widget.calculationDuration);
    GamificationState? reward;
    Object? syncError;
    try {
      reward = await widget.apiService.completeCarbonFootprint(result.annualKg);
    } catch (error) {
      syncError = error;
    }
    await minimumRevealDelay;
    if (!mounted) return;

    unawaited(EcoHaptics.heavy());
    setState(() {
      _reward = reward;
      _syncError = syncError;
      _stage = _CarbonStage.result;
    });
  }

  Future<void> _previous() async {
    if (_currentPage == 0) {
      Navigator.of(context).pop();
      return;
    }
    unawaited(EcoHaptics.light());
    setState(() => _currentPage--);
    await _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _select(CarbonQuestion question, int optionIndex) {
    EcoHaptics.selection();
    setState(() => _selectedOptions[question.id] = optionIndex);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _CarbonStage.calculating,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Karbon Ayak İzi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (_stage) {
              _CarbonStage.survey => _buildSurvey(),
              _CarbonStage.calculating => const _CalculatingView(),
              _CarbonStage.result => _ResultView(
                result: _footprint!,
                reward: _reward,
                syncError: _syncError,
                onStart: () {
                  EcoHaptics.light();
                  Navigator.of(context).pop(true);
                },
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSurvey() {
    final colors = Theme.of(context).colorScheme;
    final progress = (_currentPage + 1) / carbonQuestions.length;
    return Column(
      key: const ValueKey('carbon-survey'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Soru ${_currentPage + 1} / ${carbonQuestions.length}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%${(progress * 100).round()}',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 7),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: carbonQuestions.length,
            itemBuilder: (context, index) {
              final question = carbonQuestions[index];
              return _QuestionPage(
                question: question,
                selectedIndex: _selectedOptions[question.id],
                onSelected: (optionIndex) => _select(question, optionIndex),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _previous,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(54, 52),
                    ),
                    child: Icon(
                      _currentPage == 0
                          ? Icons.close_rounded
                          : Icons.arrow_back_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _currentPage == carbonQuestions.length - 1
                          ? Icons.calculate_outlined
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _currentPage == carbonQuestions.length - 1
                          ? 'Karbonumu Hesapla'
                          : 'Devam Et',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.selectedIndex,
    required this.onSelected,
  });

  final CarbonQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visual = _categoryVisual(question.category);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.category,
                    style: TextStyle(
                      color: visual.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              question.question,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Yıllık karbon etkine en yakın seçeneği işaretle.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 22),
            for (var index = 0; index < question.options.length; index++) ...[
              _CarbonOptionCard(
                option: question.options[index],
                accent: visual.color,
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
              if (index < question.options.length - 1)
                const SizedBox(height: 11),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarbonOptionCard extends StatelessWidget {
  const _CarbonOptionCard({
    required this.option,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final CarbonAnswerOption option;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 82),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: selected ? 0.18 : 0.07),
                  colors.surface,
                ),
                colors.surface.withValues(alpha: 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? accent : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? accent : colors.outline,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: _contrastOn(accent),
                              size: 19,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _weightLabel(option.kgOfCo2),
                      style: TextStyle(
                        color: option.kgOfCo2 < 0 ? Colors.green : accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _weightLabel(int kg) => switch (kg) {
    < 0 => '$kg kg',
    0 => '0 kg',
    _ => '+$kg kg',
  };
}

class _CalculatingView extends StatefulWidget {
  const _CalculatingView();

  @override
  State<_CalculatingView> createState() => _CalculatingViewState();
}

class _CalculatingViewState extends State<_CalculatingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      key: const ValueKey('carbon-calculating'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 260,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _CarbonRadarPainter(
                    progress: _controller.value,
                    color: colors.primary,
                    textColor: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Karbon motoru çalışıyor',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Text(
                '${(_controller.value * 17030).round().toString().padLeft(5, '0')} kg CO₂e',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '20 yaşam göstergesi yıllık etkiye dönüştürülüyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarbonRadarPainter extends CustomPainter {
  const _CarbonRadarPainter({
    required this.progress,
    required this.color,
    required this.textColor,
  });

  final double progress;
  final Color color;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [0.34, 0.67, 1.0]) {
      canvas.drawCircle(center, radius * scale, gridPaint);
    }
    for (var index = 0; index < 8; index++) {
      final angle = index * math.pi / 4;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        gridPaint,
      );
    }

    final sweepAngle = progress * math.pi * 2 - math.pi / 2;
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.65), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(math.cos(sweepAngle), math.sin(sweepAngle)) * radius,
      sweepPaint,
    );
    canvas.drawCircle(center, 7, Paint()..color = color.withValues(alpha: 0.9));

    for (var index = 0; index < 12; index++) {
      final angle = index * math.pi / 6 + progress * 0.35;
      final distance = radius * (0.44 + (index % 3) * 0.18);
      final value = ((progress * 97 + index * 17) % 100).round();
      final painter = TextPainter(
        text: TextSpan(
          text: value.toString().padLeft(2, '0'),
          style: TextStyle(
            color: textColor.withValues(alpha: 0.48),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center +
            Offset(math.cos(angle), math.sin(angle)) * distance -
            Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CarbonRadarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor;
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.reward,
    required this.syncError,
    required this.onStart,
  });

  final CarbonFootprintResult result;
  final GamificationState? reward;
  final Object? syncError;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final visual = _tierVisual(result.tier);
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('carbon-result'),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.76, end: 1),
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Opacity(opacity: scale.clamp(0, 1).toDouble(), child: child),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            children: [
              Container(
                height: 196,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      visual.color,
                      Color.alphaBlend(
                        colors.secondary.withValues(alpha: 0.28),
                        visual.color,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      visual.icon,
                      color: _contrastOn(visual.color),
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${result.annualTons.toStringAsFixed(2)} Ton',
                      style: TextStyle(
                        color: _contrastOn(visual.color),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${result.annualKg} kg CO₂e / yıl',
                      style: TextStyle(
                        color: _contrastOn(
                          visual.color,
                        ).withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                result.tier.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: visual.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                visual.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              GlassPanel(
                tint: visual.color.withValues(alpha: 0.16),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: visual.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        syncError != null
                            ? 'Sonucun hesaplandı; görev ödülü sunucuya kaydedilemedi.'
                            : reward == null
                            ? 'Karbon sonucun hesaplandı.'
                            : reward!.pointsAwarded > 0
                            ? '+${reward!.pointsAwarded} Eko Puan ve Karbon Bilinci rozeti kazandın.'
                            : 'Karbon Bilinci görevi daha önce tamamlandı.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: visual.color,
                  foregroundColor: _contrastOn(visual.color),
                ),
                icon: const Icon(Icons.eco_rounded),
                label: const Text('Karbonunu Sıfırlamaya Başla!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _categoryVisual(String category) =>
    switch (category) {
      'Ulaşım ve Seyahat' => (
        icon: Icons.commute_rounded,
        color: const Color(0xFF2574A9),
      ),
      'Beslenme ve Tüketim' => (
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF3E8C57),
      ),
      'Ev ve Enerji' => (
        icon: Icons.energy_savings_leaf_rounded,
        color: const Color(0xFFD18421),
      ),
      'Alışveriş ve Atık' => (
        icon: Icons.recycling_rounded,
        color: const Color(0xFF8B5BA5),
      ),
      _ => (icon: Icons.devices_rounded, color: const Color(0xFF3D7C7A)),
    };

({IconData icon, Color color, String message}) _tierVisual(
  CarbonFootprintTier tier,
) => switch (tier) {
  CarbonFootprintTier.natureGuardian => (
    icon: Icons.eco_rounded,
    color: const Color(0xFF23834B),
    message:
        'Düşük karbonlu alışkanlıkların güçlü. Bu etkiyi koruyup çevrene örnek olabilirsin.',
  ),
  CarbonFootprintTier.openToGrowth => (
    icon: Icons.trending_up_rounded,
    color: const Color(0xFFE08A18),
    message:
        'İyi bir başlangıçtasın. Ulaşım ve ev enerjisindeki birkaç değişiklik büyük fark yaratabilir.',
  ),
  CarbonFootprintTier.carbonMonster => (
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFC83F43),
    message:
        'Yıllık etkin yüksek; ama her güçlü dönüşüm net bir ölçümle başlar. İlk azaltım planın hazır.',
  ),
};

Color _contrastOn(Color color) =>
    color.computeLuminance() > 0.48 ? Colors.black : Colors.white;
