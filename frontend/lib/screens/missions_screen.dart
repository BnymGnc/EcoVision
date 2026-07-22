import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'carbon_footprint_screen.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({
    required this.points,
    required this.apiService,
    super.key,
  });

  final int points;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final missions = <_MissionData>[
      _MissionData(
        title: '5 plastik şişe tara',
        description: 'Geri dönüştürülebilir plastiği doğadan uzak tut.',
        icon: Icons.local_drink_outlined,
        progress: (points / 50).clamp(0, 1),
        progressLabel: '${(points ~/ 10).clamp(0, 5)} / 5 tarama',
        reward: 50,
        unlocked: true,
      ),
      const _MissionData(
        title: '1 topluluk etkinliğine katıl',
        description: 'Daha temiz bir şehir için komşularınla buluş.',
        icon: Icons.groups_2_outlined,
        progress: 0,
        progressLabel: '0 / 1 etkinlik',
        reward: 100,
        unlocked: true,
      ),
      _MissionData(
        title: 'Eko Kahraman ol',
        description: 'Bu görevi açmak için 100 puana ulaş.',
        icon: Icons.workspace_premium_outlined,
        progress: (points / 100).clamp(0, 1),
        progressLabel: '${points.clamp(0, 100)} / 100 puan',
        reward: 150,
        unlocked: points >= 50,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Görevlerim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Küçük adımlar, kalıcı etki',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Puan kazanmak ve rozet açmak için eko görevleri tamamla.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          _CarbonFootprintMission(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => CarbonFootprintScreen(apiService: apiService),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final mission in missions) ...[
            _MissionCard(mission: mission),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CarbonFootprintMission extends StatelessWidget {
  const _CarbonFootprintMission({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.co2_rounded,
                  color: colors.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Karbon Ayak İzini Hesapla',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '4 kısa soru • +75 puan',
                      style: TextStyle(
                        color: colors.onPrimaryContainer.withAlpha(190),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});

  final _MissionData mission;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final complete = mission.progress >= 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mission.unlocked
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    mission.unlocked ? mission.icon : Icons.lock_outline,
                    color: mission.unlocked
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '+${mission.reward} puan',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  complete ? Icons.check_circle : Icons.lock_open_outlined,
                  color: complete ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mission.description,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: mission.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: colors.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                mission.progressLabel,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionData {
  const _MissionData({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.progressLabel,
    required this.reward,
    required this.unlocked,
  });

  final String title;
  final String description;
  final IconData icon;
  final double progress;
  final String progressLabel;
  final int reward;
  final bool unlocked;
}
