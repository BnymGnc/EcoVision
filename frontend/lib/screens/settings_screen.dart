import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/theme_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'superuser_dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.apiService, super.key});
  final ApiService apiService;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _missionKey = 'settings.mission_reminders',
      _communityKey = 'settings.community_updates';
  bool _missions = true, _community = true, _uploading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        _missions = p.getBool(_missionKey) ?? true;
        _community = p.getBool(_communityKey) ?? true;
      });
  }

  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> _logout() async {
    final theme = ThemeScope.of(context);
    await widget.apiService.logout();
    theme.unbindUser();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
      (_) => false,
    );
  }

  Future<void> _upload() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 86,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await widget.apiService.uploadProfilePicture(file.path);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiService.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Header(
            name: user?.fullName ?? 'EcoVision Kullanıcısı',
            email: user?.email ?? '',
            picture: user?.profilePictureUrl,
          ),
          const SizedBox(height: 22),
          const _Label('Hesap'),
          _Group(
            children: [
              _Item(
                icon: Icons.person_outline,
                title: 'Profili Düzenle',
                subtitle: 'Ad, yaş ve konum bilgileri',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EditProfileScreen(apiService: widget.apiService),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _Item(
                icon: Icons.photo_camera_outlined,
                title: 'Profil Fotoğrafı',
                subtitle: _uploading ? 'Yükleniyor...' : 'Yeni fotoğraf seç',
                onTap: _uploading ? null : _upload,
              ),
              _Item(
                icon: Icons.lock_outline,
                title: 'Parolayı Değiştir',
                subtitle: 'Hesap güvenliğini güncelle',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChangePasswordScreen(apiService: widget.apiService),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('Görünüm ve Dil'),
          _Group(
            children: [
              _Item(
                icon: Icons.palette_outlined,
                title: 'Tema Seçimi',
                subtitle: ThemeScope.of(context).selected.label,
                onTap: _themeSheet,
              ),
              _Item(
                icon: Icons.language_rounded,
                title: 'Dil',
                subtitle: 'Türkçe',
                onTap: _languageSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('Bildirim Tercihleri'),
          _Group(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.flag_outlined),
                title: const Text('Görev Hatırlatmaları'),
                subtitle: const Text('Seri ve görev uyarıları'),
                value: _missions,
                onChanged: (v) {
                  setState(() => _missions = v);
                  _set(_missionKey, v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.groups_outlined),
                title: const Text('Topluluk Güncellemeleri'),
                subtitle: const Text('Davetler ve şehir etkinlikleri'),
                value: _community,
                onChanged: (v) {
                  setState(() => _community = v);
                  _set(_communityKey, v);
                },
              ),
            ],
          ),
          if (user?.isSuperuser ?? false) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withAlpha(80),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text(
                  'Superuser Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Raporlar, yayınlar ve platform moderasyonu',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SuperuserDashboardScreen(apiService: widget.apiService),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _Group(
            children: [
              _Item(
                icon: Icons.logout_rounded,
                title: 'Çıkış Yap',
                subtitle: 'Bu cihazdaki oturumu kapat',
                destructive: true,
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'EcoVision • Gizlilik odaklı yerel yapay zeka',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _themeSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final controller = ThemeScope.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tema Seçimi',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...AppThemeKind.values.map(
                (theme) => ListTile(
                  leading: CircleAvatar(backgroundColor: theme.swatch),
                  title: Text(
                    theme.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(theme.description),
                  trailing: controller.selected == theme
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    controller.select(theme);
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Future<void> _languageSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle),
              title: Text('Türkçe'),
              subtitle: Text('Etkin dil'),
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.language),
              title: Text('İngilizce'),
              subtitle: Text('Yakında'),
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.language),
              title: Text('Almanca'),
              subtitle: Text('Yakında'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.email, this.picture});
  final String name, email;
  final String? picture;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 30,
        backgroundImage: picture == null ? null : NetworkImage(picture!),
        child: picture == null ? const Icon(Icons.person_outline) : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(email, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const Divider(height: 1, indent: 62),
        ],
      ],
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
      subtitle: Text(subtitle),
      trailing: destructive ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
