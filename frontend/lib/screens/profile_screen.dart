import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../models/gamification_state.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/admin_panel.dart';
import 'change_password_screen.dart';
import 'eco_market_screen.dart';
import 'edit_profile_screen.dart';
import 'education_guide_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'missions_screen.dart';
import 'scan_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late Future<_ProfileData> _profileFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_ProfileData> _loadProfile() async {
    final results = await Future.wait([
      widget.apiService.fetchCurrentUser(),
      widget.apiService.getRecentScans(),
      widget.apiService.fetchGamificationState(),
    ]);
    return _ProfileData(
      user: results[0] as UserProfile,
      scans: results[1] as List<ScanResult>,
      gamification: results[2] as GamificationState,
    );
  }

  Future<void> _refresh() async {
    final next = _loadProfile();
    setState(() {
      _profileFuture = next;
    });
    await next;
  }

  Future<void> _uploadPicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 86,
    );
    if (image == null) {
      return;
    }

    setState(() => _isUploading = true);
    try {
      await widget.apiService.uploadProfilePicture(image.path);
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _logout() async {
    await widget.apiService.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
      (_) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ProfileLoadingState();
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final data = snapshot.requireData;
            return ValueListenableBuilder<int>(
              valueListenable: widget.apiService.pointsListenable,
              builder: (context, livePoints, _) {
                final points = livePoints;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ProfileHeader(
                                    user: data.user,
                                    points: points,
                                    isUploading: _isUploading,
                                    onUpload: _uploadPicture,
                                  ),
                                  const SizedBox(height: 24),
                                  const _SectionTitle(
                                    title: 'Your Eco Impact',
                                    subtitle:
                                        'Every scan adds up to a cleaner future',
                                  ),
                                  const SizedBox(height: 12),
                                  _ImpactStats(scans: data.scans),
                                  const SizedBox(height: 26),
                                  const _SectionTitle(
                                    title: 'Rozetler',
                                    subtitle:
                                        'Milestones from your zero-waste journey',
                                  ),
                                  const SizedBox(height: 12),
                                  _BadgesRow(
                                    points: points,
                                    carbonFootprintCompleted: data
                                        .gamification
                                        .carbonFootprintCompleted,
                                  ),
                                  const SizedBox(height: 14),
                                  _LeaderboardSnippet(
                                    onTap: () =>
                                        _open(const LeaderboardScreen()),
                                  ),
                                  const SizedBox(height: 26),
                                  const _SectionTitle(title: 'Account'),
                                  const SizedBox(height: 12),
                                  _ProfileMenu(
                                    onEditProfile: () =>
                                        _open(const EditProfileScreen()),
                                    onChangePassword: () =>
                                        _open(const ChangePasswordScreen()),
                                    onMissions: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MissionsScreen(
                                            points: points,
                                            apiService: widget.apiService,
                                          ),
                                        ),
                                      );
                                      if (mounted) {
                                        await _refresh();
                                      }
                                    },
                                    onEcoMarket: () => _open(
                                      EcoMarketScreen(
                                        apiService: widget.apiService,
                                      ),
                                    ),
                                    onEducationGuide: () =>
                                        _open(const EducationGuideScreen()),
                                    onLeaderboard: () =>
                                        _open(const LeaderboardScreen()),
                                    onHistory: () => _open(
                                      ScanHistoryScreen(scans: data.scans),
                                    ),
                                    onSettings: () =>
                                        _open(const SettingsScreen()),
                                    onLogout: _logout,
                                  ),
                                  if (data.user.isSuperuser) ...[
                                    const SizedBox(height: 26),
                                    const _SectionTitle(
                                      title: 'Platform Administration',
                                      subtitle: 'Superuser controls',
                                    ),
                                    const SizedBox(height: 12),
                                    AdminPanel(apiService: widget.apiService),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.points,
    required this.isUploading,
    required this.onUpload,
  });

  final UserProfile user;
  final int points;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withAlpha(36),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: colors.surface,
                backgroundImage: user.profilePictureUrl == null
                    ? null
                    : NetworkImage(user.profilePictureUrl!),
                child: user.profilePictureUrl == null
                    ? Text(
                        _initials(user),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton.filled(
                  tooltip: 'Change profile photo',
                  onPressed: isUploading ? null : onUpload,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.secondary,
                    foregroundColor: colors.onSecondary,
                  ),
                  icon: isUploading
                      ? SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onSecondary,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 19),
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 190, maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? 'EcoVision Member' : user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onPrimary.withAlpha(205)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.onPrimary.withAlpha(48)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        size: 20,
                        color: colors.tertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$points Eco Points',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(UserProfile user) {
    final first = user.name.isEmpty ? 'E' : user.name[0];
    final last = user.surname.isEmpty ? 'V' : user.surname[0];
    return '${first.toUpperCase()}${last.toUpperCase()}';
  }
}

class _ImpactStats extends StatelessWidget {
  const _ImpactStats({required this.scans});

  final List<ScanResult> scans;

  @override
  Widget build(BuildContext context) {
    final recycled = scans.where((scan) => scan.isRecyclable).length;
    final stats = [
      _ImpactData(
        label: 'CO₂ Saved',
        value: '${(recycled * 0.3).toStringAsFixed(1)} kg',
        icon: Icons.cloud_outlined,
        color: const Color(0xFF1976D2),
        background: const Color(0xFFE3F2FD),
      ),
      _ImpactData(
        label: 'Items Recycled',
        value: '$recycled',
        icon: Icons.recycling_rounded,
        color: const Color(0xFF2E7D32),
        background: const Color(0xFFE8F5E9),
      ),
      _ImpactData(
        label: 'Water Saved',
        value: '${(recycled * 3.6).round()} L',
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF00838F),
        background: const Color(0xFFE0F7FA),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 680) {
          return Row(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                Expanded(child: _ImpactCard(data: stats[index])),
                if (index < stats.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                SizedBox(width: 178, child: _ImpactCard(data: stats[index])),
                if (index < stats.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.data});

  final _ImpactData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 126,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          Text(
            data.value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({
    required this.points,
    required this.carbonFootprintCompleted,
  });

  final int points;
  final bool carbonFootprintCompleted;

  @override
  Widget build(BuildContext context) {
    final badges = [
      _BadgeData(
        title: 'Green Step',
        icon: Icons.directions_walk_outlined,
        color: const Color(0xFF43A047),
        unlocked: points > 0,
      ),
      _BadgeData(
        title: 'Eco Hero',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFFF9A825),
        unlocked: points >= AppConstants.ecoHeroThreshold,
      ),
      _BadgeData(
        title: 'Planet Ally',
        icon: Icons.public_rounded,
        color: const Color(0xFF1976D2),
        unlocked: points >= 100,
      ),
      _BadgeData(
        title: 'Carbon Conscious',
        icon: Icons.co2_rounded,
        color: const Color(0xFF00838F),
        unlocked: carbonFootprintCompleted,
      ),
    ];

    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _BadgeCard(data: badges[index]),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.data});

  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.unlocked ? colors.surface : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: data.unlocked ? data.color.withAlpha(80) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: data.unlocked
                  ? data.color.withAlpha(25)
                  : colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.unlocked ? data.icon : Icons.lock_outline,
              color: data.unlocked ? data.color : colors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            data.unlocked ? 'Unlocked' : 'Locked',
            style: TextStyle(
              color: data.unlocked ? data.color : colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSnippet extends StatelessWidget {
  const _LeaderboardSnippet({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFF9A825)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rank: #4 in Your City',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Just 30 points from the top three',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6D5A00)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF8D6E00)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onMissions,
    required this.onEcoMarket,
    required this.onEducationGuide,
    required this.onLeaderboard,
    required this.onHistory,
    required this.onSettings,
    required this.onLogout,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onMissions;
  final VoidCallback onEcoMarket;
  final VoidCallback onEducationGuide;
  final VoidCallback onLeaderboard;
  final VoidCallback onHistory;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      _MenuData('Edit Profile', Icons.person_outline, onEditProfile),
      _MenuData('Change Password', Icons.lock_outline, onChangePassword),
      _MenuData('Görevlerim', Icons.flag_outlined, onMissions),
      _MenuData('Eco-Market', Icons.storefront_outlined, onEcoMarket),
      _MenuData(
        'Waste Encyclopedia',
        Icons.menu_book_outlined,
        onEducationGuide,
      ),
      _MenuData('Liderlik Tablosu', Icons.leaderboard_outlined, onLeaderboard),
      _MenuData('Tarama Geçmişi', Icons.history_rounded, onHistory),
      _MenuData('Ayarlar', Icons.settings_outlined, onSettings),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _MenuTile(data: items[index]),
            const Divider(height: 1, indent: 62),
          ],
          _MenuTile(
            data: _MenuData(
              'Çıkış Yap',
              Icons.logout_rounded,
              onLogout,
              destructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.data});

  final _MenuData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = data.destructive ? colors.error : colors.onSurface;
    return ListTile(
      minTileHeight: 58,
      leading: Icon(data.icon, color: color),
      title: Text(
        data.title,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      trailing: data.destructive
          ? null
          : Icon(Icons.chevron_right, color: Colors.grey.shade500),
      onTap: data.onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Building your eco dashboard...'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 14),
            const Text(
              'We could not load your profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.user,
    required this.scans,
    required this.gamification,
  });

  final UserProfile user;
  final List<ScanResult> scans;
  final GamificationState gamification;
}

class _ImpactData {
  const _ImpactData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
}

class _BadgeData {
  const _BadgeData({
    required this.title,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool unlocked;
}

class _MenuData {
  const _MenuData(
    this.title,
    this.icon,
    this.onTap, {
    this.destructive = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}
