import 'package:flutter/material.dart';

import '../models/gamification_state.dart';
import '../services/api_service.dart';

class EcoMarketScreen extends StatefulWidget {
  const EcoMarketScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<EcoMarketScreen> createState() => _EcoMarketScreenState();
}

class _EcoMarketScreenState extends State<EcoMarketScreen> {
  late Future<GamificationState> _stateFuture;
  String? _redeemingKey;

  @override
  void initState() {
    super.initState();
    _stateFuture = widget.apiService.fetchGamificationState();
  }

  Future<void> _reload() async {
    final next = widget.apiService.fetchGamificationState();
    setState(() {
      _stateFuture = next;
    });
    await next;
  }

  Future<void> _redeem(_MarketItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Text('Use ${item.cost} Eco Points to unlock ${item.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _redeemingKey = item.key);
    try {
      final state = await widget.apiService.redeemReward(item.key);
      if (!mounted) {
        return;
      }
      setState(() {
        _stateFuture = Future.value(state);
        _redeemingKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _redeemingKey = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eco-Market')),
      body: FutureBuilder<GamificationState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MarketError(onRetry: _reload);
          }

          final state = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _MarketHero(points: state.totalPoints),
                const SizedBox(height: 26),
                const _SectionHeading(
                  title: 'Avatar Evolution',
                  subtitle: 'Grow your character as your impact grows.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 270,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarItems.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _avatarItems[index];
                      final owned = item.cost == 0 || state.hasReward(item.key);
                      return _AvatarCard(
                        item: item,
                        owned: owned,
                        current: _isCurrentAvatar(state, item),
                        canAfford: state.totalPoints >= item.cost,
                        loading: _redeemingKey == item.key,
                        onUnlock: () => _redeem(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionHeading(
                  title: 'Rewards With Real Impact',
                  subtitle: 'Turn earned points into something tangible.',
                ),
                const SizedBox(height: 12),
                for (final item in _impactItems) ...[
                  _ImpactRewardCard(
                    item: item,
                    owned: state.hasReward(item.key),
                    canAfford: state.totalPoints >= item.cost,
                    loading: _redeemingKey == item.key,
                    onRedeem: () => _redeem(item),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isCurrentAvatar(GamificationState state, _MarketItem item) {
    if (state.hasReward('avatar_planet_guardian')) {
      return item.key == 'avatar_planet_guardian';
    }
    if (state.hasReward('avatar_eco_warrior')) {
      return item.key == 'avatar_eco_warrior';
    }
    return item.key == 'avatar_stickman';
  }
}

class _MarketHero extends StatelessWidget {
  const _MarketHero({required this.points});

  final int points;

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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.onPrimary.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: colors.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Eco Wallet',
                  style: TextStyle(color: colors.onPrimary.withAlpha(205)),
                ),
                const SizedBox(height: 3),
                Text(
                  '$points points',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.eco_rounded, color: colors.tertiaryContainer, size: 34),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.item,
    required this.owned,
    required this.current,
    required this.canAfford,
    required this.loading,
    required this.onUnlock,
  });

  final _MarketItem item;
  final bool owned;
  final bool current;
  final bool canAfford;
  final bool loading;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? colors.primary : colors.outlineVariant,
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: item.color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, color: item.color, size: 70),
                  if (!owned)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Icon(
                        Icons.lock_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (owned)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  current ? Icons.check_circle : Icons.inventory_2_outlined,
                  color: colors.primary,
                  size: 19,
                ),
                Text(
                  current ? 'Current' : 'Owned',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: loading || !canAfford ? null : onUnlock,
                child: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('${item.cost} pts'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImpactRewardCard extends StatelessWidget {
  const _ImpactRewardCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.loading,
    required this.onRedeem,
  });

  final _MarketItem item;
  final bool owned;
  final bool canAfford;
  final bool loading;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: item.color.withAlpha(28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (owned)
              Chip(
                avatar: const Icon(Icons.check, size: 16),
                label: const Text('Redeemed'),
              )
            else
              FilledButton.tonal(
                onPressed: loading || !canAfford ? null : onRedeem,
                child: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('${item.cost} pts'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant)),
      ],
    );
  }
}

class _MarketError extends StatelessWidget {
  const _MarketError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 52),
          const SizedBox(height: 12),
          const Text(
            'The market is unavailable right now',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _MarketItem {
  const _MarketItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final String subtitle;
  final int cost;
  final IconData icon;
  final Color color;
}

const _avatarItems = [
  _MarketItem(
    key: 'avatar_stickman',
    title: 'Level 1: Stickman',
    subtitle: 'Every climate hero starts somewhere.',
    cost: 0,
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF607D8B),
  ),
  _MarketItem(
    key: 'avatar_eco_warrior',
    title: 'Level 2: Eco-Warrior',
    subtitle: 'Equipped for everyday action.',
    cost: 150,
    icon: Icons.shield_outlined,
    color: Color(0xFF2E7D32),
  ),
  _MarketItem(
    key: 'avatar_planet_guardian',
    title: 'Level 3: Planet Guardian',
    subtitle: 'A champion for the whole planet.',
    cost: 400,
    icon: Icons.public_rounded,
    color: Color(0xFF1565C0),
  ),
];

const _impactItems = [
  _MarketItem(
    key: 'impact_tree',
    title: 'Plant a Tree',
    subtitle: 'Fund one verified tree planting action.',
    cost: 500,
    icon: Icons.park_outlined,
    color: Color(0xFF2E7D32),
  ),
  _MarketItem(
    key: 'impact_coffee',
    title: 'Free Coffee',
    subtitle: 'Redeem a reusable-cup coffee with a partner café.',
    cost: 300,
    icon: Icons.coffee_outlined,
    color: Color(0xFF8D6E63),
  ),
];
