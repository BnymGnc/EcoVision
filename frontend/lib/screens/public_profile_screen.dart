import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../services/api_service.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    required this.apiService,
    required this.userId,
    super.key,
  });
  final ApiService apiService;
  final int userId;
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<PublicProfile> _profile;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(
    () => _profile = widget.apiService.fetchPublicProfile(widget.userId),
  );
  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) {
        _message(success);
        _reload();
      }
    } catch (e) {
      if (mounted) _message(e.toString());
    }
  }

  Future<void> _report() async {
    final reasons = ['Spam', 'Uygunsuz içerik', 'Taciz', 'Sahte profil'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Kullanıcıyı Bildir',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            ...reasons.map(
              (r) => ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(context, r),
              ),
            ),
          ],
        ),
      ),
    );
    if (reason != null)
      await _run(
        () => widget.apiService.reportUser(widget.userId, reason),
        'Bildirimin alındı.',
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EcoVision Profili'),
      actions: [
        if (widget.userId != widget.apiService.currentUser?.id)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') _report();
              if (v == 'block')
                _run(
                  () => widget.apiService.blockUser(widget.userId),
                  'Kullanıcı engellendi.',
                );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Bildir'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('Engelle'),
                ),
              ),
            ],
          ),
      ],
    ),
    body: FutureBuilder<PublicProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: Text(snapshot.error.toString()),
            ),
          );
        final p = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: p.profilePictureUrl == null
                    ? null
                    : NetworkImage(p.profilePictureUrl!),
                child: p.profilePictureUrl == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              '${p.city} • Avatar Seviye ${p.avatarLevel}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.eco_outlined,
                    value: '${p.totalPoints}',
                    label: 'Eko Puan',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(
                    icon: Icons.local_fire_department_outlined,
                    value: '${p.streakCount}',
                    label: 'Günlük Seri',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(
                    icon: Icons.favorite_outline,
                    value: '${p.likeCount}',
                    label: 'Beğeni',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.userId != widget.apiService.currentUser?.id)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _run(
                        p.liked
                            ? () => widget.apiService.unlikeProfile(p.id)
                            : () => widget.apiService.likeProfile(p.id),
                        p.liked ? 'Beğeni kaldırıldı.' : 'Profil beğenildi.',
                      ),
                      icon: Icon(
                        p.liked ? Icons.favorite : Icons.favorite_border,
                      ),
                      label: Text(p.liked ? 'Beğendin' : 'Beğen'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: p.friendshipStatus == null
                          ? () => _run(
                              () => widget.apiService.sendFriendRequest(p.id),
                              'Arkadaşlık isteği gönderildi.',
                            )
                          : null,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(
                        p.friendshipStatus == 'ACCEPTED'
                            ? 'Arkadaşın'
                            : p.friendshipStatus == 'PENDING'
                            ? 'İstek Bekliyor'
                            : 'Arkadaş Ekle',
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              'Rozetler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (p.badges.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Henüz rozet yok'),
                  subtitle: Text(
                    'Serini büyütüp atık tarayarak ilk rozetini kazan.',
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.badges
                    .map(
                      (b) => Chip(
                        avatar: const Icon(Icons.workspace_premium, size: 18),
                        label: Text(b.title),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    height: 108,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
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
