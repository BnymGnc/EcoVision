import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_module.dart';
import '../services/api_service.dart';
import 'academy_quiz_screen.dart';

class EducationDetailScreen extends StatelessWidget {
  const EducationDetailScreen({
    required this.module,
    required this.apiService,
    required this.alreadyCompleted,
    super.key,
  });

  final AcademyModule module;
  final ApiService? apiService;
  final bool alreadyCompleted;

  Future<void> _startQuiz(BuildContext context) async {
    if (alreadyCompleted) return;
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<EducationCompletionResult>(
      MaterialPageRoute<EducationCompletionResult>(
        builder: (_) =>
            AcademyQuizScreen(module: module, apiService: apiService),
      ),
    );
    if (!context.mounted || result == null) return;
    Navigator.of(context).pop(result.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
              sliver: SliverList.list(
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 40,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          module.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        if (alreadyCompleted) ...[
                          const SizedBox(height: 14),
                          _CompletedLabel(colors: colors),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ders İçeriği',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectionArea(
                    child: Text(
                      module.contentBody,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.65,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.quiz_rounded,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Geçmek için 3 sorudan en az 2 tanesini doğru cevaplamalısın.',
                            style: TextStyle(
                              color: colors.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: alreadyCompleted
                        ? null
                        : () => _startQuiz(context),
                    icon: Icon(
                      alreadyCompleted
                          ? Icons.verified_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      alreadyCompleted
                          ? 'Bu Modül Tamamlandı'
                          : 'Sınavı Başlat',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedLabel extends StatelessWidget {
  const _CompletedLabel({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 7),
          const Text(
            'Tamamlandı',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
