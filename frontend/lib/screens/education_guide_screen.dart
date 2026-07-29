import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_module.dart';
import '../services/academy_repository.dart';
import '../services/api_service.dart';
import 'education_detail_screen.dart';

class WasteGuideScreen extends StatefulWidget {
  const WasteGuideScreen({this.apiService, this.modules, super.key});

  final ApiService? apiService;
  final List<AcademyModule>? modules;

  @override
  State<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

class EducationGuideScreen extends WasteGuideScreen {
  const EducationGuideScreen({ApiService? apiService, super.key})
    : super(apiService: apiService);
}

class _WasteGuideScreenState extends State<WasteGuideScreen> {
  List<AcademyModule> _modules = const [];
  Set<String> _completed = const {};
  bool _loading = true;
  String? _loadError;
  String? _progressWarning;

  ApiService? get _apiService => widget.apiService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _progressWarning = null;
      });
    }
    try {
      final modules =
          widget.modules ?? await const AcademyRepository().loadModules();
      Set<String> completed = const {};
      String? progressWarning;
      if (_apiService != null) {
        try {
          completed = await _apiService!.fetchEducationProgress();
        } catch (_) {
          progressWarning =
              'İlerleme bilgisi alınamadı. Modülleri yine de inceleyebilirsin.';
        }
      }
      if (!mounted) return;
      setState(() {
        _modules = modules;
        _completed = completed;
        _progressWarning = progressWarning;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is FormatException
            ? error.message.toString()
            : 'Akademi içeriği yüklenemedi.';
      });
    }
  }

  Future<void> _openModule(AcademyModule module) async {
    HapticFeedback.selectionClick();
    final completedCategoryId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => EducationDetailScreen(
          module: module,
          apiService: _apiService,
          alreadyCompleted: _completed.contains(module.categoryId),
        ),
      ),
    );
    if (!mounted || completedCategoryId == null) return;
    setState(() => _completed = {..._completed, completedCategoryId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eko-Akademi')),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const _AcademyLoading();
    }
    if (_loadError != null) {
      return _AcademyError(message: _loadError!, onRetry: _load);
    }

    final completedCount = _modules
        .where((module) => _completed.contains(module.categoryId))
        .length;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _modules.length + 2,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 14 : 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AcademyHeader(
            completedCount: completedCount,
            moduleCount: _modules.length,
          );
        }
        if (index == 1) {
          return _progressWarning == null
              ? const SizedBox.shrink()
              : _ProgressWarning(message: _progressWarning!);
        }
        final module = _modules[index - 2];
        final completed = _completed.contains(module.categoryId);
        return _ModuleCard(
          module: module,
          index: index - 2,
          completed: completed,
          onTap: () => _openModule(module),
        );
      },
    );
  }
}

class _AcademyHeader extends StatelessWidget {
  const _AcademyHeader({
    required this.completedCount,
    required this.moduleCount,
  });

  final int completedCount;
  final int moduleCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = moduleCount == 0 ? 0.0 : completedCount / moduleCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: colors.onPrimaryContainer,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Atığını tanı, etkini büyüt',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bilimsel modülleri tamamla, kısa sınavları geç ve Eko Puan kazan.',
            style: TextStyle(
              color: colors.onPrimaryContainer.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: colors.surface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedCount / $moduleCount',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.index,
    required this.completed,
    required this.onTap,
  });

  final AcademyModule module;
  final int index;
  final bool completed;
  final VoidCallback onTap;

  static const _icons = [
    Icons.recycling_rounded,
    Icons.local_drink_rounded,
    Icons.battery_charging_full_rounded,
    Icons.water_drop_rounded,
    Icons.forest_rounded,
    Icons.energy_savings_leaf_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = index.isEven ? colors.primary : colors.tertiary;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icons[index % _icons.length], color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      completed ? 'Tamamlandı' : '3 soruluk sınav',
                      style: TextStyle(
                        color: completed
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: completed
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('completed'),
                        color: colors.primary,
                        size: 30,
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        key: ValueKey('open'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressWarning extends StatelessWidget {
  const _ProgressWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademyLoading extends StatelessWidget {
  const _AcademyLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: List.generate(
        6,
        (index) => Container(
          height: index == 0 ? 170 : 82,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _AcademyError extends StatelessWidget {
  const _AcademyError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 90),
        Icon(
          Icons.menu_book_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Akademi içeriği açılamadı',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar Dene'),
        ),
      ],
    );
  }
}
