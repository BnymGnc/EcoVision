import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_module.dart';
import '../services/api_service.dart';

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
    HapticFeedback.selectionClick();
    setState(() {
      _confirmed = true;
      if (_selectedOption == _question.correctOptionIndex) {
        _correctCount++;
      }
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
      HapticFeedback.mediumImpact();
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
      unawaited(HapticFeedback.heavyImpact());
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
      appBar: AppBar(title: const Text('Akademi Sınavı')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _finished ? _resultView() : _questionView(),
        ),
      ),
    );
  }

  Widget _questionView() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(_questionIndex),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Soru ${_questionIndex + 1} / ${widget.module.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '$_correctCount doğru',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_questionIndex + 1) / widget.module.questions.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 28),
          Text(
            _question.questionText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: _question.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _QuizOption(
                  label: _question.options[index],
                  selected: _selectedOption == index,
                  confirmed: _confirmed,
                  correct: index == _question.correctOptionIndex,
                  onTap: _confirmed
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedOption = index);
                        },
                );
              },
            ),
          ),
          if (_confirmed) ...[
            Text(
              _selectedOption == _question.correctOptionIndex
                  ? 'Harika, doğru cevap!'
                  : 'Doğru cevap: ${_question.options[_question.correctOptionIndex]}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _selectedOption == _question.correctOptionIndex
                    ? colors.primary
                    : colors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _submitting || _selectedOption == null
                ? null
                : _confirmed
                ? _next
                : _confirmAnswer,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
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
    return Center(
      key: ValueKey(_passed),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: (_passed ? colors.primary : colors.error).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _passed
                    ? Icons.workspace_premium_rounded
                    : Icons.school_outlined,
                size: 62,
                color: _passed ? colors.primary : colors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _passed ? 'Modülü Tamamladın!' : 'Bir Kez Daha Deneyelim',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '3 sorudan $_correctCount tanesini doğru cevapladın.',
              textAlign: TextAlign.center,
            ),
            if (_passed && _completion != null) ...[
              const SizedBox(height: 18),
              Text(
                _completion!.pointsAwarded > 0
                    ? '+${_completion!.pointsAwarded} Eko Puan'
                    : 'Bu modülün ödülü daha önce alındı',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _passed
                  ? () => Navigator.of(context).pop(_completion)
                  : _restart,
              icon: Icon(_passed ? Icons.check_rounded : Icons.replay_rounded),
              label: Text(_passed ? 'Akademiye Dön' : 'Tekrar Dene'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = confirmed && (correct || selected);
    final color = confirmed && correct
        ? colors.primary
        : confirmed && selected
        ? colors.error
        : colors.primary;
    return Material(
      color: highlighted
          ? color.withValues(alpha: 0.11)
          : selected
          ? colors.primaryContainer
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected || highlighted ? color : colors.outlineVariant,
              width: selected || highlighted ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                confirmed && correct
                    ? Icons.check_circle_rounded
                    : confirmed && selected
                    ? Icons.cancel_rounded
                    : selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected || highlighted
                    ? color
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
