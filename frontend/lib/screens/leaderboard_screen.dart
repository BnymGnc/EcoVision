import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../core/turkey_locations.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import '../widgets/privacy_aware_avatar.dart';
import 'public_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String? _city;

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
            Tab(icon: Icon(Icons.public_rounded), text: 'Tüm şehirler'),
            Tab(icon: Icon(Icons.people_outline_rounded), text: 'Arkadaşlarım'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('leaderboard-city-${_city ?? 'all'}'),
                  initialValue: _city ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Şehir',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tüm şehirler'),
                    ),
                    for (final city in TurkishLocations.provinces.keys)
                      DropdownMenuItem(value: city, child: Text(city)),
                  ],
                  onChanged: (value) =>
                      setState(() => _city = value == '' ? null : value),
                ),
              ),
              Expanded(
                child: _LeaderboardTab(
                  key: ValueKey(_city),
                  apiService: widget.apiService,
                  global: true,
                  city: _city,
                  emptyMessage: 'Bu sıralamada henüz kullanıcı yok.',
                  leagueLabel: _city == null
                      ? 'Genel Sıralama'
                      : 'Şehir Sıralaması',
                ),
              ),
            ],
          ),
          _LeaderboardTab(
            apiService: widget.apiService,
            loader: widget.apiService.fetchFriendsLeaderboard,
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
    this.loader,
    this.global = false,
    this.city,
    required this.emptyMessage,
    required this.leagueLabel,
    super.key,
  });

  final ApiService apiService;
  final Future<List<LeaderboardEntry>> Function()? loader;
  final bool global;
  final String? city;
  final String emptyMessage;
  final String leagueLabel;

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<LeaderboardEntry>> _future;
  final List<LeaderboardEntry> _more = [];
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 0;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LeaderboardEntry>> _load() async {
    if (!widget.global) return widget.loader!();
    final generation = _generation;
    final result = await widget.apiService.fetchLeaderboard(city: widget.city);
    if (mounted && generation == _generation) _hasMore = result.hasMore;
    return result.items;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiService.fetchLeaderboard(
        city: widget.city,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _page++;
        _more.addAll(result.items);
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Diğer kullanıcılar yüklenemedi. Tekrar deneyebilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _refresh() async {
    _generation++;
    _more.clear();
    _page = 0;
    _hasMore = false;
    _loadingMore = false;
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      /* The error view retains retry. */
    }
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
        final entries = [...?snapshot.data, ..._more];
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 32),
              children: [_EmptyLeaderboard(message: widget.emptyMessage)],
            ),
          );
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
            itemCount: entries.length + 1 + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _LeaderboardHero(
                  label: widget.leagueLabel,
                  city: widget.global
                      ? (widget.city ?? 'Türkiye')
                      : 'Arkadaşlarım',
                  rank: current?.rank,
                  points: current?.totalPoints,
                );
              }
              if (index == entries.length + 1) {
                return TextButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(
                    _loadingMore ? 'Yükleniyor…' : 'Diğer kullanıcılar',
                  ),
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
                  rank == null ? 'Eko Puan sıralaması' : 'Sıran: #$rank',
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
