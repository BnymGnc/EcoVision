import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

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
    final user = await widget.apiService.fetchCurrentUser();
    final scans = await widget.apiService.getRecentScans();
    return _ProfileData(user: user, scans: scans);
  }

  Future<void> _refresh() async {
    setState(() => _profileFuture = _loadProfile());
    await _profileFuture;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final data = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ProfileHeader(
                    user: data.user,
                    isUploading: _isUploading,
                    onUpload: _uploadPicture,
                  ),
                  const SizedBox(height: 18),
                  _BadgesCard(points: data.user.totalPoints),
                  if (data.user.isSuperuser) ...[
                    const SizedBox(height: 18),
                    _AdminPanel(apiService: widget.apiService),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Scan history',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (data.scans.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No scans yet. Your first scan appears here.',
                        ),
                      ),
                    )
                  else
                    for (final scan in data.scans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              scan.isRecyclable
                                  ? Icons.recycling_rounded
                                  : Icons.delete_outline,
                            ),
                            title: Text(scan.material),
                            subtitle: Text(
                              scan.scannedAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                            trailing: Icon(
                              scan.isRecyclable
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: scan.isRecyclable
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
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
    required this.isUploading,
    required this.onUpload,
  });

  final UserProfile user;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: user.profilePictureUrl == null
                      ? null
                      : NetworkImage(user.profilePictureUrl!),
                  child: user.profilePictureUrl == null
                      ? Icon(
                          Icons.person,
                          size: 42,
                          color: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                IconButton.filled(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Chip(
                    avatar: const Icon(Icons.stars_rounded, size: 18),
                    label: Text('${user.totalPoints} points'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final progress = (points / AppConstants.ecoHeroThreshold).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            _BadgeTile(
              title: 'Green Step',
              subtitle: 'Complete your first successful scan',
              unlocked: points > 0,
            ),
            _BadgeTile(
              title: 'Eco Hero',
              subtitle: 'Reach ${AppConstants.ecoHeroThreshold} points',
              unlocked: points >= AppConstants.ecoHeroThreshold,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        unlocked ? Icons.workspace_premium : Icons.lock_outline,
        color: unlocked ? colorScheme.primary : Colors.black38,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: unlocked
          ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
          : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AdminPanel extends StatefulWidget {
  const _AdminPanel({required this.apiService});

  final ApiService apiService;

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  final _emailController = TextEditingController();
  late Future<List<UserProfile>> _usersFuture;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = widget.apiService.fetchAdminUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    setState(() => _usersFuture = widget.apiService.fetchAdminUsers());
    await _usersFuture;
  }

  Future<void> _assignAdmin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return;
    }

    setState(() => _isAssigning = true);
    try {
      await widget.apiService.assignAdminRole(email);
      _emailController.clear();
      await _refreshUsers();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin role assigned.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Admin Panel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Grant admin by email',
                prefixIcon: Icon(Icons.mail_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _isAssigning ? null : _assignAdmin,
              icon: _isAssigning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Assign Admin'),
            ),
            const Divider(height: 28),
            FutureBuilder<List<UserProfile>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.error.toString()),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _refreshUsers,
                        child: const Text('Retry users'),
                      ),
                    ],
                  );
                }

                final users = snapshot.requireData;
                return Column(
                  children: [
                    for (final user in users.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: user.profilePictureUrl == null
                              ? null
                              : NetworkImage(user.profilePictureUrl!),
                          child: user.profilePictureUrl == null
                              ? Text(user.name.isEmpty ? '?' : user.name[0])
                              : null,
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(user.email),
                        trailing: Chip(label: Text(user.role)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.user, required this.scans});

  final UserProfile user;
  final List<ScanResult> scans;
}
