import 'package:flutter/material.dart';

import '../models/login_activity.dart';
import '../models/user_profile.dart';
import 'privacy_aware_avatar.dart';
import 'premium_ui.dart';

class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    required this.user,
    required this.streakFuture,
    required this.onEditAvatar,
    required this.onLoginHistory,
    super.key,
  });

  final UserProfile user;
  final Future<Map<String, dynamic>> streakFuture;
  final VoidCallback onEditAvatar;
  final ValueChanged<LoginStreakSummary?> onLoginHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = user.fullName.isEmpty ? 'EcoVision Kahramanı' : user.fullName;
    final location = [
      user.city,
      user.district,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PrivacyAwareAvatar(
                        userId: user.id,
                        currentUserId: user.id,
                        radius: 60,
                        backgroundColor: colors.primaryContainer,
                        borderColor: colors.primary.withValues(alpha: 0.3),
                        profilePictureUrl: user.profilePictureUrl,
                        profileImagePreference: user.profileImagePreference,
                        selectedAvatarPath: user.selectedAvatarPath,
                        avatarLevel: user.equippedAvatarLevel,
                        highestAvatarLevel: user.currentAvatarLevel,
                        adult: user.adult,
                        profileVisibility: user.profileVisibility,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: IconButton.filled(
                              tooltip: 'Avatarı Düzenle',
                              onPressed: () {
                                EcoHaptics.light();
                                onEditAvatar();
                              },
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 21),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Tooltip(
                message: name,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
              if (user.username.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  '@${user.username}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  location,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _IdentityValue(
                      value: '${user.totalPoints}',
                      label: 'Eko Puan',
                      color: colors.primary,
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: VerticalDivider(color: colors.outlineVariant),
                  ),
                  Expanded(
                    child: _IdentityValue(
                      value: '${user.equippedAvatarLevel}',
                      label: 'Avatar Seviyesi',
                      color: colors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: streakFuture,
                builder: (context, snapshot) {
                  final summary = LoginStreakSummary.tryParse(snapshot.data);
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final label = loading
                      ? 'Seri yükleniyor…'
                      : summary == null
                      ? 'Giriş günlerini görüntüle'
                      : '${summary.currentStreak} gün giriş serisi';
                  return Semantics(
                    button: true,
                    enabled: !loading,
                    label: label,
                    onTap: loading ? null : () => onLoginHistory(summary),
                    child: ExcludeSemantics(
                      child: Material(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const ValueKey('profile-login-streak'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: loading ? null : () => onLoginHistory(summary),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  color: colors.onSecondaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: text.labelLarge?.copyWith(
                                      color: colors.onSecondaryContainer,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colors.onSecondaryContainer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (user.streakFreezeCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${user.streakFreezeCount} seri dondurucu',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityValue extends StatelessWidget {
  const _IdentityValue({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
