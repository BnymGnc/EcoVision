import 'dart:async';

import 'package:flutter/material.dart';

import '../models/academy_module.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class AcademyQuizScreen extends StatefulWidget {
  const AcademyQuizScreen({
    required this.module,
    required this.apiService,
    super.key,
  });

  final AcademyModule module;
  final ApiService? apiService;

  @override
  State<AcademyQuizScreen> createState() => _AcademyQuizScreenState();
}

class _AcademyQuizScreenState extends State<AcademyQuizScreen> {
  int _questionIndex = 0;
  int? _selectedOption;
  int _correctCount = 0;
  bool _confirmed = false;
  bool _submitting = false;
  bool _finished = false;
  bool _passed = false;
  String? _error;
  EducationCompletionResult? _completion;

  AcademyQuestion get _question => widget.module.questions[_questionIndex];

  void _confirmAnswer() {
    if (_selectedOption == null || _confirmed) return;
    EcoHaptics.selection();
    setState(() {
      _confirmed = true;
      if (_selectedOption == _question.correctOptionIndex) _correctCount++;
    });
  }

  Future<void> _next() async {
    if (!_confirmed) return;
    if (_questionIndex < widget.module.questions.length - 1) {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
        _confirmed = false;
      });
      return;
    }
    _passed = _correctCount >= 2;
    if (!_passed) {
      await EcoHaptics.light();
      setState(() => _finished = true);
      return;
    }
    await _claimCompletion();
  }

  Future<void> _claimCompletion() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final completion = widget.apiService == null
          ? EducationCompletionResult(
              categoryId: widget.module.categoryId,
              newlyCompleted: true,
              pointsAwarded: 0,
              totalPoints: 0,
              message: 'Test modu tamamlandı',
            )
          : await widget.apiService!.completeEducationModule(
              widget.module.categoryId,
            );
      unawaited(EcoHaptics.heavy());
      if (!mounted) return;
      setState(() {
        _completion = completion;
        _submitting = false;
        _finished = true;
        _passed = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  void _restart() {
    setState(() {
      _questionIndex = 0;
      _selectedOption = null;
      _correctCount = 0;
      _confirmed = false;
      _submitting = false;
      _finished = false;
      _passed = false;
      _error = null;
      _completion = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akademi Sınavı',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.05, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _finished ? _resultView() : _questionView(),
        ),
      ),
    );
  }

  Widget _questionView() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(_questionIndex),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Soru ${_questionIndex + 1} / ${widget.module.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Icon(Icons.bolt_rounded, color: colors.primary, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_correctCount doğru',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _QuizProgress(
            value: (_questionIndex + 1) / widget.module.questions.length,
          ),
          const SizedBox(height: 30),
          Text(
            _question.questionText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: _question.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _QuizOption(
                label: _question.options[index],
                selected: _selectedOption == index,
                confirmed: _confirmed,
                correct: index == _question.correctOptionIndex,
                onTap: _confirmed
                    ? null
                    : () {
                        EcoHaptics.selection();
                        setState(() => _selectedOption = index);
                      },
              ),
            ),
          ),
          if (_confirmed) ...[
            _AnswerFeedback(
              correct: _selectedOption == _question.correctOptionIndex,
              correctAnswer: _question.options[_question.correctOptionIndex],
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _submitting || _selectedOption == null
                ? null
                : _confirmed
                ? _next
                : _confirmAnswer,
            child: _submitting
                ? SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.onPrimary,
                    ),
                  )
                : Text(
                    _confirmed
                        ? _questionIndex == widget.module.questions.length - 1
                              ? 'Sonucu Gör'
                              : 'Sonraki Soru'
                        : 'Cevabı Onayla',
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
            TextButton(
              onPressed: _claimCompletion,
              child: const Text('Puanı Tekrar Al'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultView() {
    final colors = Theme.of(context).colorScheme;
    final accent = _passed ? colors.primary : colors.error;
    return Center(
      key: ValueKey(_passed),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 720),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: Opacity(opacity: scale.clamp(0, 1), child: child),
          ),
          child: GlassPanel(
            padding: const EdgeInsets.all(28),
            tint: accent.withValues(alpha: 0.10),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.65)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 34,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _passed
                        ? Icons.workspace_premium_rounded
                        : Icons.school_rounded,
                    size: 64,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  _passed ? 'Modülü Tamamladın!' : 'Bir Kez Daha Deneyelim',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  '3 sorudan $_correctCount tanesini doğru cevapladın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (_passed && _completion != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _completion!.pointsAwarded > 0
                          ? '+${_completion!.pointsAwarded} Eko Puan'
                          : 'Bu modülün ödülü daha önce alındı',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _passed
                      ? () => Navigator.of(context).pop(_completion)
                      : _restart,
                  icon: Icon(
                    _passed ? Icons.check_rounded : Icons.replay_rounded,
                  ),
                  label: Text(_passed ? 'Akademiye Dön' : 'Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizOption extends StatefulWidget {
  const _QuizOption({
    required this.label,
    required this.selected,
    required this.confirmed,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool confirmed;
  final bool correct;
  final VoidCallback? onTap;

  @override
  State<_QuizOption> createState() => _QuizOptionState();
}

class _QuizOptionState extends State<_QuizOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = widget.confirmed && (widget.correct || widget.selected);
    final color = widget.confirmed && widget.correct
        ? colors.primary
        : widget.confirmed && widget.selected
        ? colors.error
        : colors.primary;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: highlighted
              ? color.withValues(alpha: widget.correct ? 0.16 : 0.10)
              : widget.selected
              ? colors.primaryContainer.withValues(alpha: 0.72)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.selected || highlighted
                ? color
                : colors.outlineVariant.withValues(alpha: 0.7),
            width: widget.selected || highlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? color.withValues(alpha: 0.18)
                  : colors.shadow.withValues(alpha: 0.04),
              blurRadius: highlighted ? 24 : 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: colors.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = false),
            onTapCancel: widget.onTap == null
                ? null
                : () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.selected || highlighted
                          ? color
                          : colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.confirmed && widget.correct
                          ? Icons.check_rounded
                          : widget.confirmed && widget.selected
                          ? Icons.close_rounded
                          : widget.selected
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: widget.selected || highlighted
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.correct, required this.correctAnswer});

  final bool correct;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = correct ? colors.primary : colors.error;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            correct ? Icons.celebration_rounded : Icons.lightbulb_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              correct ? 'Harika, doğru cevap!' : 'Doğru cevap: $correctAnswer',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizProgress extends StatelessWidget {
  const _QuizProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 12,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        clipBehavior: Clip.antiAlias,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                ),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.36),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
