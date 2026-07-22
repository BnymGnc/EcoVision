import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../models/social_models.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'scan_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.apiService,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });
  final ApiService apiService;
  final int notificationCount;
  final VoidCallback? onNotifications;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = _fetch();
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
    });
    await _future;
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(apiService: widget.apiService),
      ),
    );
    if (mounted) await _refresh();
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
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(message: snapshot.error.toString(), onRetry: _refresh);
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Persona(user: data.user),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.stars_rounded,
                      value: '${data.user.totalPoints}',
                      label: 'Eko Puan',
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Metric(
                      icon: Icons.local_fire_department_rounded,
                      value: '${data.user.streakCount}',
                      label: 'Günlük Seri',
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Metric(
                      icon: Icons.workspace_premium_outlined,
                      value: '${data.publicProfile.badges.length}',
                      label: 'Rozet',
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
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

class _Persona extends StatelessWidget {
  const _Persona({required this.user});
  final UserProfile user;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: colors.surface,
            backgroundImage: user.profilePictureUrl == null
                ? null
                : NetworkImage(user.profilePictureUrl!),
            child: user.profilePictureUrl == null
                ? Text(
                    _initials(user),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  )
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 210, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? 'EcoVision Kahramanı' : user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${user.city}${user.district.isEmpty ? '' : ' • ${user.district}'}',
                  style: TextStyle(color: colors.onPrimary.withAlpha(210)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.eco_outlined, size: 18),
                      label: Text('Avatar Seviye ${user.equippedAvatarLevel}'),
                    ),
                    if (user.streakFreezeCount > 0)
                      Chip(
                        avatar: const Icon(Icons.ac_unit, size: 18),
                        label: Text('${user.streakFreezeCount} Dondurucu'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(UserProfile u) =>
      '${u.name.isEmpty ? 'E' : u.name[0]}${u.surname.isEmpty ? 'V' : u.surname[0]}'
          .toUpperCase();
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
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
    if (items.isEmpty)
      return const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('İlk rozetin seni bekliyor'),
          subtitle: Text('Seri oluştur, plastik ve cam atıkları tara.'),
        ),
      );
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
              borderRadius: BorderRadius.circular(8),
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
