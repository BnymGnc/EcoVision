import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.apiService, super.key});
  final ApiService apiService;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _fetchAndMarkRead();
  }

  Future<List<AppNotification>> _fetchAndMarkRead() async {
    final items = await widget.apiService.fetchNotifications();
    if (items.any((item) => !item.read)) {
      await widget.apiService.markAllNotificationsRead();
      return widget.apiService.fetchNotifications();
    }
    return items;
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bildirimler'),
      actions: [
        IconButton(
          tooltip: 'Tümünü okundu işaretle',
          onPressed: () async {
            await widget.apiService.markAllNotificationsRead();
            if (mounted) _refresh();
          },
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: FutureBuilder<List<AppNotification>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const EcoShimmerList(itemCount: 6);
        if (snapshot.hasError)
          return _State(
            icon: Icons.cloud_off_outlined,
            title: 'Bildirimler yüklenemedi',
            message: snapshot.error.toString(),
            action: _refresh,
          );
        final items = snapshot.data ?? const [];
        if (items.isEmpty)
          return const _State(
            icon: Icons.notifications_none_rounded,
            title: 'Henüz bildirimin yok',
            message:
                'Yeni rozetler, davetler ve şehir duyuruları burada görünecek.',
          );
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _Tile(item: items[index]),
          ),
        );
      },
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final AppNotification item;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (item.type) {
      'SOCIAL' => (Icons.favorite_outline, colors.secondary),
      'GAMIFICATION' => (Icons.workspace_premium_outlined, colors.tertiary),
      'LOCATION' => (Icons.location_city_outlined, colors.primary),
      'STREAK' => (Icons.local_fire_department_outlined, colors.error),
      _ => (Icons.campaign_outlined, colors.primary),
    };
    return Container(
      decoration: BoxDecoration(
        color: item.read
            ? colors.surface
            : colors.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: item.read
              ? colors.outlineVariant
              : colors.primary.withAlpha(80),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(24),
          child: Icon(icon, color: color),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(item.message),
            const SizedBox(height: 5),
            Text(
              _time(item.createdAt),
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        trailing: item.read
            ? null
            : Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  String _time(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _State extends StatelessWidget {
  const _State({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ],
      ),
    ),
  );
}
