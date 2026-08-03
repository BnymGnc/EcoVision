import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/avatar_tier.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

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
    await EcoHaptics.selection();
    setState(() => _equippingLevel = tier.level);
    try {
      await widget.apiService.equipAvatar(tier.level);
      await _refresh();
      await EcoHaptics.heavy();
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
      appBar: AppBar(
        title: const Text(
          'Avatar Yolculuğu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<_AvatarData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EcoShimmerList(
              itemCount: 6,
              showHeader: true,
              padding: EdgeInsets.fromLTRB(20, 10, 20, 32),
            );
          }
          if (snapshot.hasError) {
            return _AvatarState(
              icon: Icons.cloud_off_rounded,
              title: 'Avatar yolculuğun şu an yüklenemedi',
              subtitle: 'Bağlantını kontrol edip yeniden deneyebilirsin.',
              onRetry: _refresh,
            );
          }

          final data = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
              itemCount: data.tiers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _EvolutionHeader(user: data.user);
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
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.onPrimary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                user.selectedAvatarPath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.eco_rounded, color: colors.onPrimary, size: 42),
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEVİYE ${user.equippedAvatarLevel}',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Eko Kahraman Yolun',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: colors.tertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${user.lifetimePoints} toplam Eko Puan',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
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
}

class _TierPathNode extends StatefulWidget {
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
  State<_TierPathNode> createState() => _TierPathNodeState();
}

class _TierPathNodeState extends State<_TierPathNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
      lowerBound: 0,
      upperBound: 1,
    );
    if (widget.tier.equipped) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TierPathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tier.equipped && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.tier.equipped && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tier = widget.tier;
    final accent = tier.unlocked ? colors.primary : colors.outline;
    final nodeWidth = MediaQuery.sizeOf(context).width.clamp(320, 760) * 0.82;
    return Column(
      children: [
        Align(
          alignment: widget.isLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              width: nodeWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: tier.equipped
                        ? colors.primary.withValues(
                            alpha: 0.18 + (_pulse.value * 0.20),
                          )
                        : colors.shadow.withValues(alpha: 0.04),
                    blurRadius: tier.equipped ? 22 + (_pulse.value * 18) : 24,
                    spreadRadius: tier.equipped ? _pulse.value * 2 : 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color: tier.equipped
                      ? colors.primaryContainer.withValues(alpha: 0.88)
                      : colors.surface.withValues(
                          alpha: tier.unlocked ? 0.84 : 0.58,
                        ),
                  child: InkWell(
                    onTap: tier.unlocked ? widget.onEquip : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: tier.equipped
                              ? colors.primary.withValues(alpha: 0.80)
                              : colors.onSurface.withValues(alpha: 0.12),
                          width: tier.equipped ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _AvatarOrb(tier: tier, accent: accent),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SEVİYE ${tier.level}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tier.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${tier.requiredLifetimePoints} toplam puan',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isLoading)
                            const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          else
                            Icon(
                              tier.equipped
                                  ? Icons.verified_rounded
                                  : tier.unlocked
                                  ? Icons.arrow_forward_ios_rounded
                                  : Icons.lock_rounded,
                              color: accent,
                              size: tier.equipped ? 27 : 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showConnector)
          Align(
            alignment: widget.isLeft
                ? const Alignment(-0.58, 0)
                : const Alignment(0.58, 0),
            child: SizedBox(
              width: 18,
              height: 38,
              child: CustomPaint(
                painter: _PathConnectorPainter(
                  color: accent,
                  unlocked: tier.unlocked,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarOrb extends StatelessWidget {
  const _AvatarOrb({required this.tier, required this.accent});

  final AvatarTier tier;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/avatars/avatar_level_${tier.level}.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        tier.unlocked ? Icons.accessibility_new_rounded : Icons.lock_rounded,
        color: accent,
        size: 34,
      ),
    );
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: tier.unlocked ? 0.10 : 0.06),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.75), width: 2.5),
      ),
      child: ClipOval(
        child: tier.unlocked
            ? image
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Opacity(opacity: 0.46, child: image),
              ),
      ),
    );
  }
}

class _PathConnectorPainter extends CustomPainter {
  const _PathConnectorPainter({required this.color, required this.unlocked});

  final Color color;
  final bool unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..color = unlocked ? color : color.withValues(alpha: 0.48)
      ..strokeWidth = unlocked ? 5 : 3
      ..strokeCap = StrokeCap.round;
    if (unlocked) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(
        Offset(x, 1),
        Offset(x, size.height - 1),
        Paint()
          ..color = color.withValues(alpha: 0.24)
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    for (double y = 0; y < size.height; y += 9) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + 4).clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PathConnectorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.unlocked != unlocked;
}

class _AvatarState extends StatelessWidget {
  const _AvatarState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 54, color: colors.primary),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarData {
  const _AvatarData({required this.user, required this.tiers});

  final UserProfile user;
  final List<AvatarTier> tiers;
}
