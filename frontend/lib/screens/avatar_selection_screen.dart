import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({
    required this.apiService,
    required this.user,
    super.key,
  });

  final ApiService apiService;
  final UserProfile user;

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  int? _savingLevel;
  late String _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.user.selectedAvatarPath;
  }

  Future<void> _select(int level) async {
    if (level > widget.user.currentAvatarLevel || _savingLevel != null) return;
    await EcoHaptics.selection();
    final path = _pathFor(level);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avatarı Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 150,
              child: Image.asset(path, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu avatarı profil resmin olarak ayarlamak istiyor musun?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Avatarı Seç'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingLevel = level);
    try {
      final updated = await widget.apiService.equipAvatar(level);
      if (!mounted) return;
      setState(() => _selectedPath = updated.selectedAvatarPath);
      await EcoHaptics.light();
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingLevel = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _savingLevel == null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Avatarını Seç',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.onPrimaryContainer,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mevcut Seviyen: ${widget.user.currentAvatarLevel}',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Seviyene kadar olan avatarları kullanabilirsin.',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverGrid.builder(
                itemCount: 20,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final level = index + 1;
                  return _AvatarTile(
                    level: level,
                    path: _pathFor(level),
                    locked: level > widget.user.currentAvatarLevel,
                    selected: _selectedPath == _pathFor(level),
                    saving: _savingLevel == level,
                    onTap: () => _select(level),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pathFor(int level) => 'assets/images/avatars/avatar_level_$level.png';
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.level,
    required this.path,
    required this.locked,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final int level;
  final String path;
  final bool locked;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  static const _grayscale = ColorFilter.matrix(<double>[
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
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 42),
                  child: ColorFiltered(
                    colorFilter: locked
                        ? _grayscale
                        : ColorFilter.mode(
                            colors.surface.withValues(alpha: 0),
                            BlendMode.dst,
                          ),
                    child: Opacity(
                      opacity: locked ? 0.52 : 1,
                      child: Image.asset(path, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seviye $level',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (saving)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (selected)
                      Icon(Icons.check_circle_rounded, color: colors.primary),
                  ],
                ),
              ),
              if (locked)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.12),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
