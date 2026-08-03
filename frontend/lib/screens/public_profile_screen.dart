import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import '../widgets/privacy_aware_avatar.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.apiService.fetchPublicProfile(widget.userId);
  }

  void _reload() {
    setState(() {
      _profile = widget.apiService.fetchPublicProfile(widget.userId);
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    await EcoHaptics.light();
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _message(success);
      _reload();
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    const reasons = ['Spam', 'Uygunsuz içerik', 'Taciz', 'Sahte profil'];
    final reason = await showEcoGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            const ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text(
                'Kullanıcıyı Bildir',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            ...reasons.map(
              (reason) => ListTile(
                title: Text(reason),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, reason),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (reason != null) {
      await _run(
        () => widget.apiService.reportUser(widget.userId, reason),
        'Bildirimin alındı.',
      );
    }
  }

  Future<void> _friendAction(PublicProfile profile) async {
    if (profile.friendshipStatus == 'ACCEPTED') {
      await _run(
        () => widget.apiService.removeFriend(profile.id),
        'Arkadaşlık kaldırıldı.',
      );
      return;
    }
    await _run(
      () => widget.apiService.sendFriendRequest(profile.id),
      'Arkadaşlık isteği gönderildi.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EcoVision Profili'),
      actions: [
        if (widget.userId != widget.apiService.currentUser?.id)
          PopupMenuButton<String>(
            tooltip: 'Profil işlemleri',
            onSelected: (value) {
              EcoHaptics.selection();
              if (value == 'report') _report();
              if (value == 'block') {
                _run(
                  () => widget.apiService.blockUser(widget.userId),
                  'Kullanıcı engellendi.',
                );
              }
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EcoShimmerList(
            itemCount: 4,
            showHeader: true,
            padding: EdgeInsets.all(20),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _reload);
        }
        return _ProfileBody(
          profile: snapshot.requireData,
          isOwnProfile: widget.userId == widget.apiService.currentUser?.id,
          busy: _busy,
          onLike: () {
            final profile = snapshot.requireData;
            _run(
              profile.liked
                  ? () => widget.apiService.unlikeProfile(profile.id)
                  : () => widget.apiService.likeProfile(profile.id),
              profile.liked ? 'Beğeni kaldırıldı.' : 'Profil beğenildi.',
            );
          },
          onFriend: () => _friendAction(snapshot.requireData),
        );
      },
    ),
  );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.isOwnProfile,
    required this.busy,
    required this.onLike,
    required this.onFriend,
  });

  final PublicProfile profile;
  final bool isOwnProfile;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onFriend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassPanel(
          tint: colors.primaryContainer,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              PrivacyAwareAvatar(
                userId: profile.id,
                currentUserId: isOwnProfile ? profile.id : null,
                radius: 52,
                backgroundColor: colors.surface,
                profilePictureUrl: profile.profilePictureUrl,
                profileImagePreference: profile.profileImagePreference,
                selectedAvatarPath: profile.selectedAvatarPath,
                avatarLevel: profile.avatarLevel,
                highestAvatarLevel: profile.highestAvatarLevel,
                adult: profile.adult,
                profileVisibility: profile.profileVisibility,
                friendshipStatus: profile.friendshipStatus,
              ),
              const SizedBox(height: 13),
              Text(
                profile.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (profile.username.isNotEmpty)
                Text(
                  '@${profile.username}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 4),
              Text('${profile.city} • Avatar Seviye ${profile.avatarLevel}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!profile.detailsVisible)
          _PrivateProfileNotice(waiting: profile.friendshipStatus == 'PENDING'),
        const SizedBox(height: 14),
        _PrivateAwareStats(profile: profile),
        if (!isOwnProfile) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (profile.detailsVisible) ...[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : onLike,
                    icon: Icon(
                      profile.liked ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(profile.liked ? 'Beğendin' : 'Beğen'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: profile.detailsVisible ? 1 : 2,
                child: FilledButton.icon(
                  onPressed: busy || profile.friendshipStatus == 'PENDING'
                      ? null
                      : onFriend,
                  icon: Icon(
                    profile.friendshipStatus == 'ACCEPTED'
                        ? Icons.person_remove_outlined
                        : Icons.person_add_alt_1,
                  ),
                  label: Text(_friendLabel(profile.friendshipStatus)),
                ),
              ),
            ],
          ),
        ],
        if (profile.detailsVisible) ...[
          const SizedBox(height: 26),
          Text(
            'Rozetler',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (profile.badges.isEmpty)
            const GlassPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('Henüz rozet yok'),
                subtitle: Text('İlk başarı rozeti için doğaya katkı sağla.'),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.badges
                  .map(
                    (badge) => Chip(
                      avatar: const Icon(Icons.workspace_premium, size: 18),
                      label: Text(badge.title),
                    ),
                  )
                  .toList(),
            ),
        ],
      ],
    );
  }

  String _friendLabel(String? status) => switch (status) {
    'ACCEPTED' => 'Arkadaşlıktan Çıkar',
    'PENDING' => 'İstek Bekliyor',
    _ => 'Arkadaş Ekle',
  };
}

class _PrivateAwareStats extends StatelessWidget {
  const _PrivateAwareStats({required this.profile});
  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final stats = Row(
      children: [
        Expanded(
          child: _Stat(
            icon: Icons.eco_outlined,
            value: '${profile.totalPoints}',
            label: 'Eko Puan',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            icon: Icons.local_fire_department_outlined,
            value: '${profile.streakCount}',
            label: 'Günlük Seri',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            icon: Icons.favorite_outline,
            value: '${profile.likeCount}',
            label: 'Beğeni',
          ),
        ),
      ],
    );
    return profile.detailsVisible
        ? stats
        : ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: IgnorePointer(child: stats),
          );
  }
}

class _PrivateProfileNotice extends StatelessWidget {
  const _PrivateProfileNotice({required this.waiting});
  final bool waiting;

  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Column(
      children: [
        const Icon(Icons.lock_rounded, size: 58),
        const SizedBox(height: 10),
        Text(
          'Bu profil gizlidir.',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          waiting
              ? 'Arkadaşlık isteğinizin kabul edilmesi bekleniyor.'
              : 'Detayları görmek için arkadaşlık isteği gönderin.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    child: Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 58),
          const SizedBox(height: 12),
          const Text(
            'Profil açılamadı',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
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
