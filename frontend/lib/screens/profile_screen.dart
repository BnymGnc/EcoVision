import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../models/social_models.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';
import '../models/login_activity.dart';
import '../widgets/profile_identity_header.dart';
import '../widgets/login_activity_sheet.dart';
import 'avatar_selection_screen.dart';
import 'scan_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.apiService,
    this.notificationCount = 0,
    this.onNotifications,
    this.refreshVersion = 0,
    super.key,
  });
  final ApiService apiService;
  final int notificationCount;
  final VoidCallback? onNotifications;
  final int refreshVersion;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _future;
  late Future<Map<String, dynamic>> _streakFuture;
  late Future<Map<String, dynamic>> _impactFuture;
  @override
  void initState() {
    super.initState();
    _load();
    _streakFuture = _fetchStreak();
    _impactFuture = _fetchImpact();
  }

  void _load() => _future = _fetch();
  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshVersion != oldWidget.refreshVersion) {
      _refresh();
    }
  }

  Future<Map<String, dynamic>> _fetchStreak() async {
    try {
      return await widget.apiService.fetchLoginStreak();
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, dynamic>> _fetchImpact() async {
    try {
      return await widget.apiService.fetchCarbonSummary();
    } catch (_) {
      return const {};
    }
  }

  Future<_ProfileData> _fetch() async {
    final user = await widget.apiService.fetchCurrentUser();
    final values = await Future.wait([
      widget.apiService.getRecentScans(),
      widget.apiService.fetchPublicProfile(user.id),
    ]);
    return _ProfileData(
      user: user,
      scans: values[0] as List<ScanResult>,
      publicProfile: values[1] as PublicProfile,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
      _streakFuture = _fetchStreak();
      _impactFuture = _fetchImpact();
    });
    try {
      await _future;
    } catch (_) {
      // FutureBuilder owns the retryable profile error state.
    }
  }

  Future<void> _openSettings() async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) =>
          SettingsScreen(apiService: widget.apiService, embedded: true),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openLoginHistory(LoginStreakSummary? summary) async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) =>
          LoginActivitySheet(apiService: widget.apiService, summary: summary),
    );
  }

  Future<void> _openAvatarSelection(UserProfile user) async {
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute<UserProfile>(
        builder: (_) =>
            AvatarSelectionScreen(apiService: widget.apiService, user: user),
      ),
    );
    if (updated == null || !mounted) return;

    final current = await _future;
    if (!mounted) return;
    setState(() {
      _future = Future.value(
        _ProfileData(
          user: updated,
          scans: current.scans,
          publicProfile: current.publicProfile,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Profil',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: [
        if (widget.onNotifications != null)
          NotificationBell(
            count: widget.notificationCount,
            onPressed: widget.onNotifications!,
          ),
        IconButton(
          tooltip: 'Ayarlar',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: FutureBuilder<_ProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EcoShimmerList(
            itemCount: 5,
            showHeader: true,
            padding: EdgeInsets.all(20),
          );
        }
        if (snapshot.hasError) {
          return _Error(message: snapshot.error.toString(), onRetry: _refresh);
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ProfileIdentityHeader(
                user: data.user,
                streakFuture: _streakFuture,
                onLoginHistory: _openLoginHistory,
                onEditAvatar: () => _openAvatarSelection(data.user),
              ),
              const SizedBox(height: 14),
              _EcoImpactDashboard(
                streak: data.user.streakCount,
                badgeCount: data.publicProfile.badges.length,
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: _impactFuture,
                builder: (context, snapshot) {
                  final impact = snapshot.data;
                  if (impact == null || impact.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final difference = impact['estimatedDifferenceKg'] as num?;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.eco_outlined),
                      title: Text(
                        difference == null
                            ? 'Henüz hesaplanmış atık etkisi yok'
                            : 'Tahmini fark: ${difference.toStringAsFixed(2)} kg CO₂e',
                      ),
                      subtitle: Text(
                        '${impact['declaredActionCount']} eylem · Kullanıcı beyanı',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _Title(
                title: 'Rozetler',
                subtitle: 'Doğa için kazandığın başarılar',
              ),
              const SizedBox(height: 10),
              _Badges(items: data.publicProfile.badges),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: _Title(
                      title: 'Tarama Geçmişi',
                      subtitle: 'Son geri dönüşüm hareketlerin',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ScanHistoryScreen(scans: data.scans),
                      ),
                    ),
                    child: const Text('Tümünü Gör'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (data.scans.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.document_scanner_outlined),
                    title: Text('Henüz tarama yok'),
                    subtitle: Text(
                      'İlk atığını taradığında geçmişin burada görünecek.',
                    ),
                  ),
                )
              else
                ...data.scans
                    .take(5)
                    .map(
                      (scan) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ScanTile(scan: scan),
                      ),
                    ),
            ],
          ),
        );
      },
    ),
  );
}

class _EcoImpactDashboard extends StatelessWidget {
  const _EcoImpactDashboard({required this.streak, required this.badgeCount});

  final int streak;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassPanel(
      tint: colors.surfaceContainerLow,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eco-Etki',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Tarama serisi: $streak gün  •  $badgeCount rozet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ImpactCard(
                  icon: Icons.cloud_outlined,
                  value: '—',
                  label: 'Ölçülen CO₂',
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactCard(
                  icon: Icons.water_drop_outlined,
                  value: '$streak',
                  label: 'Tarama serisi',
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactCard(
                  icon: Icons.recycling_rounded,
                  value: '$badgeCount',
                  label: 'Kazanılan rozet',
                  color: colors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 126),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

class _Badges extends StatelessWidget {
  const _Badges({required this.items});
  final List<EcoBadge> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('İlk rozetin seni bekliyor'),
          subtitle: Text('Seri oluştur, plastik ve cam atıkları tara.'),
        ),
      );
    }
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final badge = items[index];
          return Container(
            width: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withAlpha(110),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 34),
                const Spacer(),
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  badge.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.scan});
  final ScanResult scan;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          scan.isRecyclable ? Icons.recycling_rounded : Icons.delete_outline,
        ),
      ),
      title: Text(
        scan.material,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(scan.recycledInto),
      trailing: Text(
        _date(scan.scannedAt),
        style: const TextStyle(fontSize: 11),
      ),
    ),
  );
  String _date(DateTime? date) {
    if (date == null) return '';
    final d = date.toLocal();
    return '${d.day}.${d.month}\n${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
    ],
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52),
          const SizedBox(height: 10),
          const Text(
            'Profil yüklenemedi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileData {
  const _ProfileData({
    required this.user,
    required this.scans,
    required this.publicProfile,
  });
  final UserProfile user;
  final List<ScanResult> scans;
  final PublicProfile publicProfile;
}
