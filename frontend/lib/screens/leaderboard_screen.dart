import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/api_service.dart';
import 'public_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = widget.apiService.fetchCityLeaderboard();
  }

  Future<void> _refresh() async {
    final next = widget.apiService.fetchCityLeaderboard();
    setState(() {
      _leaderboardFuture = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liderlik Tablosu')),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LeaderboardError(onRetry: _refresh);
          }

          final entries = snapshot.requireData;
          if (entries.isEmpty) {
            return const Center(
              child: Text('Şehir sıralaması henüz oluşmadı.'),
            );
          }
          LeaderboardEntry? current;
          for (final entry in entries) {
            if (entry.currentUser) {
              current = entry;
              break;
            }
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _LeaderboardHero(
                  city: entries.first.city,
                  rank: current?.rank,
                  points: current?.totalPoints,
                ),
                const SizedBox(height: 22),
                for (final entry in entries) ...[
                  _RankTile(
                    entry: entry,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PublicProfileScreen(
                          apiService: widget.apiService,
                          userId: entry.userId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({
    required this.city,
    required this.rank,
    required this.points,
  });

  final String city;
  final int? rank;
  final int? points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: colors.tertiaryContainer,
            size: 54,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$city Şehir Ligi',
                  style: TextStyle(
                    color: colors.onPrimary.withAlpha(210),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
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
                    style: TextStyle(color: colors.onPrimary.withAlpha(210)),
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
    final medalColor = switch (entry.rank) {
      1 => const Color(0xFFFFB300),
      2 => const Color(0xFF78909C),
      3 => const Color(0xFFB87333),
      _ => colors.onSurfaceVariant,
    };

    return Container(
      decoration: BoxDecoration(
        color: entry.currentUser ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: entry.currentUser ? colors.primary : colors.outlineVariant,
          width: entry.currentUser ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: SizedBox(
          width: 78,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: medalColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              CircleAvatar(
                backgroundImage: entry.profilePictureUrl == null
                    ? null
                    : NetworkImage(entry.profilePictureUrl!),
                child: entry.profilePictureUrl == null
                    ? Text(_initials(entry.fullName))
                    : null,
              ),
            ],
          ),
        ),
        title: Text(
          entry.currentUser ? '${entry.fullName} (Sen)' : entry.fullName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(entry.city),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
  }
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Şehir sıralaması yüklenemedi.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
