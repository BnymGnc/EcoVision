import 'package:flutter/material.dart';

import '../models/gamification_state.dart';
import '../services/api_service.dart';
import '../widgets/mascot_celebration.dart';

class CarbonFootprintScreen extends StatefulWidget {
  const CarbonFootprintScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<CarbonFootprintScreen> createState() => _CarbonFootprintScreenState();
}

class _CarbonFootprintScreenState extends State<CarbonFootprintScreen> {
  final _pageController = PageController();
  final Map<int, _SurveyOption> _answers = {};
  int _currentPage = 0;
  bool _isSubmitting = false;
  GamificationState? _result;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_answers[_currentPage] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devam etmek için bir yanıt seç.')),
      );
      return;
    }
    if (_currentPage < _questions.length - 1) {
      setState(() => _currentPage++);
      await _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    final score = _answers.values.fold<int>(
      0,
      (total, option) => total + option.score,
    );
    setState(() => _isSubmitting = true);
    try {
      final result = await widget.apiService.completeCarbonFootprint(score);
      if (mounted) {
        setState(() {
          _result = result;
          _isSubmitting = false;
        });
        if (result.pointsAwarded > 0) {
          await MascotCelebration.show(
            context,
            detail:
                'Karbon ayak izi görevini tamamladın ve yeni rozet kazandın.',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  void _back() {
    if (_currentPage == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentPage--);
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karbon Ayak İzi')),
      body: SafeArea(
        child: _result == null ? _buildSurvey(context) : _buildResult(context),
      ),
    );
  }

  Widget _buildSurvey(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Soru ${_currentPage + 1} / ${_questions.length}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${((_currentPage + 1) / _questions.length * 100).round()}%',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentPage + 1) / _questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, index) => _QuestionPage(
              question: _questions[index],
              selected: _answers[index],
              onSelected: (answer) => setState(() => _answers[index] = answer),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _back,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_currentPage == 0 ? 'Vazgeç' : 'Geri'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _continue,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _currentPage == _questions.length - 1
                              ? Icons.eco_outlined
                              : Icons.arrow_forward,
                        ),
                  label: Text(
                    _currentPage == _questions.length - 1
                        ? 'Hesapla'
                        : 'Devam Et',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final score = _answers.values.fold<int>(
      0,
      (total, option) => total + option.score,
    );
    final colors = Theme.of(context).colorScheme;
    final rating = score <= 30
        ? 'Düşük etkili yaşam'
        : score <= 60
        ? 'İklim bilinçli başlangıç'
        : 'Gelişim için alan var';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      children: [
        Center(
          child: Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              color: colors.onPrimaryContainer,
              size: 58,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          rating,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Ayak izi puanın $score / 100. Düşük puan daha iyidir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: colors.tertiary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Karbon Bilinci Rozeti',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Icon(Icons.check_circle, color: colors.primary),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _result!.pointsAwarded > 0
                            ? '+${_result!.pointsAwarded} Eko Puan kazandın'
                            : 'Tek seferlik ödül daha önce alındı',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            score <= 30
                ? 'Örnek olmaya devam et ve bir arkadaşını topluluk temizliğine davet et.'
                : 'Haftada bir araba yolculuğunu yürüyüş, bisiklet veya toplu taşımayla değiştir.',
            style: TextStyle(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check),
          label: const Text('Görevi Bitir'),
        ),
      ],
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final _SurveyQuestion question;
  final _SurveyOption? selected;
  final ValueChanged<_SurveyOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            question.icon,
            color: colors.onPrimaryContainer,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          question.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          question.subtitle,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 22),
        for (final option in question.options) ...[
          _AnswerTile(
            option: option,
            selected: option == selected,
            onTap: () => onSelected(option),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SurveyOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(option.icon, color: selected ? colors.primary : null),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurveyQuestion {
  const _SurveyQuestion({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_SurveyOption> options;
}

class _SurveyOption {
  const _SurveyOption(this.label, this.score, this.icon);

  final String label;
  final int score;
  final IconData icon;
}

const _questions = [
  _SurveyQuestion(
    title: 'Genellikle nasıl ulaşım sağlıyorsun?',
    subtitle: 'Tipik bir haftanı en iyi anlatan seçeneği işaretle.',
    icon: Icons.commute_outlined,
    options: [
      _SurveyOption('Yürüyüş veya bisiklet', 0, Icons.directions_bike_outlined),
      _SurveyOption('Toplu taşıma', 10, Icons.directions_bus_outlined),
      _SurveyOption(
        'Elektrikli veya paylaşımlı araç',
        20,
        Icons.electric_car_outlined,
      ),
      _SurveyOption(
        'Benzinli veya dizel araç',
        30,
        Icons.directions_car_outlined,
      ),
    ],
  ),
  _SurveyQuestion(
    title: 'Beslenme biçimini hangisi anlatıyor?',
    subtitle: 'Gıda seçimleri arazi, su ve emisyonları etkiler.',
    icon: Icons.restaurant_outlined,
    options: [
      _SurveyOption('Çoğunlukla bitkisel', 5, Icons.eco_outlined),
      _SurveyOption('Dengeli ve mevsimsel', 15, Icons.ramen_dining_outlined),
      _SurveyOption('Çoğu gün et', 30, Icons.lunch_dining_outlined),
    ],
  ),
  _SurveyQuestion(
    title: 'Evinin enerjisi nasıl sağlanıyor?',
    subtitle: 'Bu hızlı ölçüm için yaklaşık yanıt yeterlidir.',
    icon: Icons.home_work_outlined,
    options: [
      _SurveyOption(
        'Çoğunlukla yenilenebilir enerji',
        5,
        Icons.solar_power_outlined,
      ),
      _SurveyOption(
        'Karma enerji planı',
        12,
        Icons.energy_savings_leaf_outlined,
      ),
      _SurveyOption('Standart şebeke enerjisi', 20, Icons.bolt_outlined),
    ],
  ),
  _SurveyQuestion(
    title: 'Ne kadar düzenli geri dönüştürüyorsun?',
    subtitle: 'Plastik, kağıt, cam ve özel atıkları düşün.',
    icon: Icons.recycling_rounded,
    options: [
      _SurveyOption('Her zaman', 0, Icons.check_circle_outline),
      _SurveyOption('Bazen', 10, Icons.autorenew_rounded),
      _SurveyOption('Nadiren', 20, Icons.delete_outline),
    ],
  ),
];
