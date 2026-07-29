import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/quest_progress.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import 'carbon_footprint_screen.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({
    required this.points,
    required this.apiService,
    super.key,
  });

  final int points;
  final ApiService apiService;

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  late Future<List<QuestProgress>> _future;
  List<QuestProgress> _quests = const [];
  String _selectedDomain = 'ALL';
  final Set<int> _busyQuestIds = {};

  static const _domains = <String, String>{
    'ALL': 'Tümü',
    'RECYCLING': 'Geri Dönüşüm',
    'TRANSPORTATION': 'Ulaşım',
    'ENERGY_SAVING': 'Enerji',
    'WATER_SAVING': 'Su',
    'COMMUNITY': 'Topluluk',
    'STREAK': 'Seri',
    'SOCIAL': 'Sosyal',
    'EDUCATION': 'Eğitim',
    'ECO_MARKET': 'Eco-Market',
    'ECO_IMPACT': 'Eko Etki',
  };

  @override
  void initState() {
    super.initState();
    _future = _fetchQuests();
  }

  Future<List<QuestProgress>> _fetchQuests() async {
    final quests = await widget.apiService.fetchQuests();
    _quests = List.unmodifiable(quests);
    return _quests;
  }

  Future<void> _refresh() async {
    try {
      final quests = await widget.apiService.fetchQuests();
      if (!mounted) return;
      setState(() {
        _quests = List.unmodifiable(quests);
        _future = SynchronousFuture(_quests);
      });
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _retry() {
    setState(() {
      _future = _fetchQuests();
    });
  }

  Future<void> _checkIn(QuestProgress quest) async {
    HapticFeedback.lightImpact();
    setState(() => _busyQuestIds.add(quest.questId));
    try {
      final updated = await widget.apiService.checkInQuest(quest.questId);
      if (!mounted) return;
      _replaceQuest(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.completed
                ? 'Görev tamamlandı. Ödülünü alabilirsin!'
                : 'İlerlemen kaydedildi.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyQuestIds.remove(quest.questId));
    }
  }

  Future<void> _claim(QuestProgress quest) async {
    final progressId = quest.progressId;
    if (progressId == null) return;
    HapticFeedback.heavyImpact();
    setState(() => _busyQuestIds.add(quest.questId));
    try {
      final result = await widget.apiService.claimQuest(progressId);
      if (!mounted) return;
      _replaceQuest(result.quest);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.workspace_premium_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Görev Tamamlandı!'),
          content: Text(
            '+${result.pointsAwarded} Eko Puan kazandın.\n'
            'Yeni bakiyen: ${result.totalPoints} puan',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Harika'),
            ),
          ],
        ),
      );
      if (mounted) {
        // Reconcile server state without replacing the visible list with a
        // transient loading/blank screen.
        await _refresh();
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyQuestIds.remove(quest.questId));
    }
  }

  void _replaceQuest(QuestProgress updated) {
    final next = [
      for (final quest in _quests)
        if (quest.questId == updated.questId) updated else quest,
    ];
    setState(() {
      _quests = List.unmodifiable(next);
      _future = SynchronousFuture(_quests);
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('ApiException: ', '')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Görevler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<QuestProgress>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EcoShimmerList(
              itemCount: 6,
              showHeader: true,
              padding: EdgeInsets.all(20),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString().replaceFirst(
                'ApiException: ',
                '',
              ),
              onRetry: _retry,
            );
          }

          final allQuests = snapshot.data ?? const <QuestProgress>[];
          final quests = _selectedDomain == 'ALL'
              ? allQuests
              : allQuests
                    .where((quest) => quest.domain == _selectedDomain)
                    .toList();
          final completed = allQuests.where((quest) => quest.completed).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _MissionHeader(
                      apiService: widget.apiService,
                      completed: completed,
                      total: allQuests.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _domains.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final entry = _domains.entries.elementAt(index);
                        return FilterChip(
                          selected: _selectedDomain == entry.key,
                          label: Text(entry.value),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDomain = entry.key);
                          },
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: _CarbonFootprintMission(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => CarbonFootprintScreen(
                            apiService: widget.apiService,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (quests.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Bu kategoride görev bulunamadı.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: quests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quest = quests[index];
                        return _QuestCard(
                          quest: quest,
                          busy: _busyQuestIds.contains(quest.questId),
                          onCheckIn: () => _checkIn(quest),
                          onClaim: () => _claim(quest),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({
    required this.apiService,
    required this.completed,
    required this.total,
  });

  final ApiService apiService;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.flag_rounded, color: colors.onPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: apiService.pointsListenable,
                  builder: (_, points, _) => Text(
                    '$points Eko Puan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completed / $total görev tamamlandı',
                  style: TextStyle(
                    color: colors.onPrimaryContainer.withAlpha(190),
                    fontWeight: FontWeight.w600,
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

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.busy,
    required this.onCheckIn,
    required this.onClaim,
  });

  final QuestProgress quest;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final domain = _domainStyle(quest.domain, colors);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: domain.color.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(domain.icon, color: domain.color),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${domain.label} • ${_scheduleLabel(quest.schedule)}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${quest.rewardPoints}',
                    style: TextStyle(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              quest.description,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: quest.progress,
                minHeight: 9,
                backgroundColor: colors.surfaceContainerHighest,
                color: quest.completed ? colors.primary : domain.color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${quest.currentAmount} / ${quest.targetAmount}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (quest.claimed)
                  const _StatusLabel(
                    icon: Icons.check_circle,
                    text: 'Ödül alındı',
                  )
                else if (quest.completed)
                  FilledButton.icon(
                    onPressed: busy ? null : onClaim,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.redeem_rounded),
                    label: const Text('Puanı Al'),
                  )
                else if (quest.checkInAvailable)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCheckIn,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_task_rounded),
                    label: const Text('İlerleme Kaydet'),
                  )
                else
                  _StatusLabel(
                    icon: Icons.sync_rounded,
                    text: quest.progress > 0
                        ? 'Devam ediyor'
                        : 'Otomatik izleniyor',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CarbonFootprintMission extends StatelessWidget {
  const _CarbonFootprintMission({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.co2_rounded, color: colors.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Karbon Ayak İzini Hesapla',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 58),
          const SizedBox(height: 14),
          const Text(
            'Görevler yüklenemedi',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message.isEmpty
                ? 'Bağlantını kontrol edip yeniden deneyebilirsin.'
                : message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Yeniden Dene'),
          ),
        ],
      ),
    ),
  );
}

({IconData icon, Color color, String label}) _domainStyle(
  String domain,
  ColorScheme colors,
) {
  return switch (domain) {
    'RECYCLING' => (
      icon: Icons.recycling_rounded,
      color: const Color(0xFF16865C),
      label: 'Geri Dönüşüm',
    ),
    'TRANSPORTATION' => (
      icon: Icons.directions_bus_rounded,
      color: const Color(0xFF2878C8),
      label: 'Ulaşım',
    ),
    'ENERGY_SAVING' => (
      icon: Icons.bolt_rounded,
      color: const Color(0xFFE09B18),
      label: 'Enerji',
    ),
    'WATER_SAVING' => (
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF1689B0),
      label: 'Su',
    ),
    'COMMUNITY' => (
      icon: Icons.groups_rounded,
      color: const Color(0xFFB45572),
      label: 'Topluluk',
    ),
    'STREAK' => (
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFE26535),
      label: 'Seri',
    ),
    'SOCIAL' => (
      icon: Icons.favorite_rounded,
      color: const Color(0xFFC34D72),
      label: 'Sosyal',
    ),
    'EDUCATION' => (
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF6B63B5),
      label: 'Eğitim',
    ),
    'ECO_MARKET' => (
      icon: Icons.storefront_rounded,
      color: const Color(0xFFBD6D24),
      label: 'Eco-Market',
    ),
    _ => (icon: Icons.eco_rounded, color: colors.primary, label: 'Eko Etki'),
  };
}

String _scheduleLabel(String schedule) {
  return switch (schedule) {
    'DAILY' => 'Günlük',
    'WEEKLY' => 'Haftalık',
    'SOCIAL' => 'Sosyal',
    'HIDDEN' => 'Gizli',
    'FACTION' => 'Takım',
    'ECO_IMPACT' => 'Eko Etki',
    _ => 'Kilometre Taşı',
  };
}
