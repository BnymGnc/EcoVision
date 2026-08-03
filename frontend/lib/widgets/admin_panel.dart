import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'privacy_aware_avatar.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
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
    setState(() {
      _usersFuture = widget.apiService.fetchAdminUsers();
    });
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
        ).showSnackBar(const SnackBar(content: Text('Yönetici rolü atandı.')));
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yönetici Paneli',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Platform rollerini yönet',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-postayla yönetici ata',
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
              label: const Text('Yönetici Ata'),
            ),
            const Divider(height: 30),
            FutureBuilder<List<UserProfile>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      const Expanded(child: Text('Kullanıcılar yüklenemedi.')),
                      TextButton(
                        onPressed: _refreshUsers,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  );
                }

                final users = snapshot.data ?? const <UserProfile>[];
                return Column(
                  children: [
                    for (final user in users.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PrivacyAwareAvatar(
                          userId: user.id,
                          currentUserId: widget.apiService.currentUser?.id,
                          avatarLevel: user.equippedAvatarLevel,
                          highestAvatarLevel: user.currentAvatarLevel,
                          profileImagePreference: user.profileImagePreference,
                          adult: user.adult,
                          profileVisibility: user.profileVisibility,
                          profilePictureUrl: user.profilePictureUrl,
                          selectedAvatarPath: user.selectedAvatarPath,
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(user.email),
                        trailing: Chip(label: Text(_roleLabel(user.role))),
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

String _roleLabel(String role) => switch (role) {
  'SUPERUSER' => 'Süper Kullanıcı',
  'ADMIN' => 'Yönetici',
  _ => 'Kullanıcı',
};
