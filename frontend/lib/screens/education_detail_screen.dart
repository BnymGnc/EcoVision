import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openSource(BuildContext context, AcademySource source) async {
    try {
      if (await launchUrl(source.url, mode: LaunchMode.externalApplication))
        return;
    } catch (_) {
      // Keep the lesson open if the platform cannot launch a browser.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaynak açılamadı. Lütfen tekrar dene.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Atık Rehberi')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: FilledButton.icon(
            onPressed: alreadyCompleted ? null : () => _startQuiz(context),
            icon: Icon(
              alreadyCompleted ? Icons.verified_rounded : Icons.quiz_outlined,
            ),
            label: Text(
              alreadyCompleted ? 'Bu Modül Tamamlandı' : 'Sınavı Başlat',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${module.readingMinutes} dk okuma · 3 soru',
                        style: texts.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (alreadyCompleted)
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.primary,
                        semanticLabel: 'Tamamlandı',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  module.title,
                  style: texts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (module.summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    module.summary,
                    style: texts.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (module.collectionRoute.isNotEmpty)
                  _Notice(
                    icon: Icons.route_outlined,
                    title: 'Nereye teslim edilir?',
                    text: module.collectionRoute,
                  ),
                const SizedBox(height: 20),
                SelectionArea(
                  child: Text(
                    module.contentBody,
                    style: texts.bodyLarge?.copyWith(height: 1.7),
                  ),
                ),
                const SizedBox(height: 20),
                if (module.safetyNote.isNotEmpty) ...[
                  _Notice(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Önce güvenlik',
                    text: module.safetyNote,
                    warning: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _LessonSection(
                  title: 'Uygun örnekler',
                  icon: Icons.checklist_rounded,
                  lines: module.acceptedExamples,
                  initiallyExpanded: true,
                ),
                _LessonSection(
                  title: 'Bu akışa dahil olmayanlar',
                  icon: Icons.block_outlined,
                  lines: module.excludedExamples,
                ),
                _LessonSection(
                  title: 'Teslimden önce hazırlık',
                  icon: Icons.fact_check_outlined,
                  lines: module.preparation,
                ),
                _LessonSection(
                  title: 'Sık yapılan hatalar',
                  icon: Icons.report_gmailerrorred_outlined,
                  lines: module.mistakes,
                ),
                if (module.aiTip.isNotEmpty)
                  _LessonSection(
                    title: 'Yapay zeka: ipuçları ve sınırlar',
                    icon: Icons.psychology_outlined,
                    lines: [module.aiTip],
                  ),
                _LessonSection(
                  title: 'Atığı azalt ve yeniden kullan',
                  icon: Icons.autorenew_rounded,
                  lines: module.reuseIdeas,
                ),
                const SizedBox(height: 20),
                Text(
                  'Bilgini sınayabilirsin',
                  style: texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '3 sorudan en az 2 doğru cevap gerekir. Modül ödülü hesap başına yalnızca bir kez verilir.',
                  style: texts.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                if (module.sources.isNotEmpty) ...[
                  const Divider(height: 36),
                  Text(
                    'Kaynaklar',
                    style: texts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İçerik kontrolü: 24 Ekim 2026. Genel bilgiler yerel kabul koşullarının yerine geçmez; teslim noktasından doğrula.',
                    style: texts.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  for (final source in module.sources)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.title, style: texts.bodyMedium),
                      subtitle: Text(source.url.host),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                      onTap: () => _openSource(context, source),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = warning
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.6,
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

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.title,
    required this.icon,
    required this.lines,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<String> lines;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return ExpansionTile(
      key: PageStorageKey(title),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: (expanded) {
        if (expanded) HapticFeedback.selectionClick();
      },
      leading: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      height: 1.6,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    lines[i],
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
