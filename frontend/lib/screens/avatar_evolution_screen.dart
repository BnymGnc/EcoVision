import 'package:flutter/material.dart';

import '../models/avatar_tier.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class AvatarEvolutionScreen extends StatefulWidget {
  const AvatarEvolutionScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<AvatarEvolutionScreen> createState() => _AvatarEvolutionScreenState();
}

class _AvatarEvolutionScreenState extends State<AvatarEvolutionScreen> {
  late Future<_AvatarData> _future;
  int? _equippingLevel;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AvatarData> _load() async {
    final values = await Future.wait([
      widget.apiService.fetchCurrentUser(),
      widget.apiService.fetchAvatarTiers(),
    ]);
    return _AvatarData(
      user: values[0] as UserProfile,
      tiers: values[1] as List<AvatarTier>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _equip(AvatarTier tier) async {
    if (!tier.unlocked || tier.equipped || _equippingLevel != null) return;
    setState(() => _equippingLevel = tier.level);
    try {
      await widget.apiService.equipAvatar(tier.level);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tier.title} artık kullanılıyor.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _equippingLevel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Gelişimi')),
      body: FutureBuilder<_AvatarData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AvatarState(
              icon: Icons.cloud_off_outlined,
              title: 'Avatar gelişim yolun yüklenemedi',
              onRetry: _refresh,
            );
          }

          final data = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              itemCount: data.tiers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _EvolutionHeader(user: data.user);
                }
                final tier = data.tiers[index - 1];
                return _TierPathNode(
                  tier: tier,
                  isLeft: tier.level.isOdd,
                  showConnector: index < data.tiers.length,
                  isLoading: _equippingLevel == tier.level,
                  onEquip: () => _equip(tier),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EvolutionHeader extends StatelessWidget {
  const _EvolutionHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.eco_rounded, color: colors.onPrimary, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.equippedAvatarLevel}. seviye kullanılıyor',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.lifetimePoints} toplam Eko Puan',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPathNode extends StatelessWidget {
  const _TierPathNode({
    required this.tier,
    required this.isLeft,
    required this.showConnector,
    required this.isLoading,
    required this.onEquip,
  });

  final AvatarTier tier;
  final bool isLeft;
  final bool showConnector;
  final bool isLoading;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = tier.unlocked ? colors.primary : colors.outline;
    return Column(
      children: [
        Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280, 520) * 0.78,
            child: Material(
              color: tier.equipped
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: tier.unlocked ? onEquip : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(28),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 3),
                        ),
                        child: Icon(
                          tier.unlocked
                              ? Icons.accessibility_new_rounded
                              : Icons.lock_outline_rounded,
                          color: accent,
                          size: 31,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tier.level}. SEVİYE',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tier.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('${tier.requiredLifetimePoints} toplam puan'),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          tier.equipped
                              ? Icons.check_circle_rounded
                              : tier.unlocked
                              ? Icons.touch_app_outlined
                              : Icons.lock_rounded,
                          color: accent,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showConnector)
          Container(
            width: 4,
            height: 28,
            margin: EdgeInsets.only(
              left: isLeft ? 62 : 0,
              right: isLeft ? 0 : 62,
            ),
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

class _AvatarState extends StatelessWidget {
  const _AvatarState({
    required this.icon,
    required this.title,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}

class _AvatarData {
  const _AvatarData({required this.user, required this.tiers});

  final UserProfile user;
  final List<AvatarTier> tiers;
}
