import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import '../widgets/privacy_aware_avatar.dart';
import 'public_profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Liderlik Tablosu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.location_city_outlined), text: 'Şehrim'),
            Tab(icon: Icon(Icons.people_outline_rounded), text: 'Arkadaşlarım'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _LeaderboardTab(
            apiService: apiService,
            loader: apiService.fetchCityLeaderboard,
            emptyMessage: 'Şehir sıralaması henüz oluşmadı.',
            leagueLabel: 'Şehir Ligi',
          ),
          _LeaderboardTab(
            apiService: apiService,
            loader: apiService.fetchFriendsLeaderboard,
            emptyMessage: 'Arkadaş sıralaman için önce arkadaş eklemelisin.',
            leagueLabel: 'Arkadaş Ligi',
          ),
        ],
      ),
    ),
  );
}

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab({
    required this.apiService,
    required this.loader,
    required this.emptyMessage,
    required this.leagueLabel,
  });

  final ApiService apiService;
  final Future<List<LeaderboardEntry>> Function() loader;
  final String emptyMessage;
  final String leagueLabel;

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<LeaderboardEntry>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _refresh() async {
    final next = widget.loader();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openProfile(int userId) async {
    if (userId <= 0) return;
    await EcoHaptics.light();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(apiService: widget.apiService, userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EcoShimmerList(
            itemCount: 7,
            showHeader: true,
            padding: EdgeInsets.fromLTRB(20, 14, 20, 32),
          );
        }
        if (snapshot.hasError) {
          return _LeaderboardError(onRetry: _refresh);
        }
        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) {
          return _EmptyLeaderboard(message: widget.emptyMessage);
        }
        final current = entries.cast<LeaderboardEntry?>().firstWhere(
          (entry) => entry?.currentUser ?? false,
          orElse: () => null,
        );
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _LeaderboardHero(
                  label: widget.leagueLabel,
                  city: entries.first.city,
                  rank: current?.rank,
                  points: current?.totalPoints,
                );
              }
              final entry = entries[index - 1];
              return _RankTile(
                entry: entry,
                onTap: () => _openProfile(entry.userId),
              );
            },
          ),
        );
      },
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({
    required this.label,
    required this.city,
    required this.rank,
    required this.points,
  });

  final String label;
  final String city;
  final int? rank;
  final int? points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassPanel(
      tint: colors.primary,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: colors.onPrimary, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$city • $label',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  rank == null ? 'Sıralamaya katıl' : 'Sıran: #$rank',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                if (points != null)
                  Text(
                    '$points Eko Puan',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.82),
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

class _RankTile extends StatelessWidget {
  const _RankTile({required this.entry, required this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final medalGradient = switch (entry.rank) {
      1 => [
        colors.tertiaryContainer,
        colors.tertiary,
        colors.onTertiaryContainer,
      ],
      2 => [
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        colors.outline,
      ],
      3 => [
        colors.secondaryContainer,
        colors.secondary,
        colors.onSecondaryContainer,
      ],
      _ => null,
    };
    return GlassPanel(
      tint: entry.currentUser ? colors.primaryContainer : colors.surface,
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: SizedBox(
          width: 78,
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: medalGradient == null
                    ? Text(
                        '#${entry.rank}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: medalGradient,
                        ).createShader(bounds),
                        child: Text(
                          '#${entry.rank}',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              PrivacyAwareAvatar(
                userId: entry.userId,
                currentUserId: entry.currentUser ? entry.userId : null,
                radius: 20,
                profilePictureUrl: entry.profilePictureUrl,
                profileImagePreference: entry.profileImagePreference,
                selectedAvatarPath: entry.selectedAvatarPath,
                avatarLevel: entry.avatarLevel,
                highestAvatarLevel: entry.highestAvatarLevel,
                adult: entry.adult,
                profileVisibility: entry.profileVisibility,
                friendshipStatus: entry.friendshipStatus,
              ),
            ],
          ),
        ),
        title: Text(
          entry.currentUser ? '${entry.fullName} (Sen)' : entry.fullName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          entry.username.isEmpty
              ? entry.city
              : '@${entry.username} • ${entry.city}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.totalPoints}',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const Text('puan', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join();
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.leaderboard_rounded,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 48),
        const SizedBox(height: 12),
        const Text('Sıralama yüklenemedi.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
      ],
    ),
  );
}
