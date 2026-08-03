import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/turkey_locations.dart';
import '../models/community_group.dart';
import '../models/event_member.dart';
import '../models/group_join_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/premium_ui.dart';
import '../widgets/privacy_aware_avatar.dart';
import 'group_chat_screen.dart';
import 'public_profile_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({
    required this.apiService,
    required this.group,
    super.key,
  });

  final ApiService apiService;
  final CommunityGroup group;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late CommunityGroup _group;
  late Future<List<GroupEvent>> _events;
  late Future<List<EventMember>> _members;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _reload();
  }

  void _reload() {
    setState(() {
      _events = widget.apiService.fetchGroupEvents(_group.id);
      _members = _loadMembersWithFriendContext();
    });
  }

  Future<List<EventMember>> _loadMembersWithFriendContext() async {
    final result = await Future.wait<Object>([
      widget.apiService.fetchCommunityGroupMembers(_group.id),
      widget.apiService.fetchFriends(),
    ]);
    return result.first as List<EventMember>;
  }

  Future<void> _openCreateEvent() async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) => CreateGroupEventSheet(
        apiService: widget.apiService,
        group: _group,
        onCreated: _reload,
      ),
    );
  }

  Future<void> _editGroup() async {
    final updated = await showEcoGlassSheet<CommunityGroup>(
      context: context,
      builder: (_) =>
          _EditGroupSheet(apiService: widget.apiService, group: _group),
    );
    if (updated == null || !mounted) return;
    setState(() => _group = updated);
    _reload();
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grup silinsin mi?'),
        content: const Text(
          'Grup, etkinlikleri ve sohbet geçmişi kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grubu Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteCommunityGroup(_group.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _manageMembers() async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) => _RoleAwareMembersSheet(
        apiService: widget.apiService,
        group: _group,
        onChanged: _reload,
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grup Profili'),
        actions: [
          if (_group.isFounder)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editGroup();
                if (value == 'members') _manageMembers();
                if (value == 'delete') _deleteGroup();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Grubu Düzenle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'members',
                  child: ListTile(
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('Üyeleri Yönet'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_group.isFounder)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Grubu Sil',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 7,
                    child: _group.coverImageUrl == null
                        ? ColoredBox(
                            color: colors.primaryContainer,
                            child: Icon(
                              Icons.groups_2_rounded,
                              size: 72,
                              color: colors.primary,
                            ),
                          )
                        : Image.network(
                            _group.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.primaryContainer,
                              child: const Icon(
                                Icons.groups_2_rounded,
                                size: 72,
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _group.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (_group.isAdmin)
                              Chip(
                                avatar: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 18,
                                ),
                                label: const Text('Yönetici'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(child: Text(_group.locationLabel)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(_group.description),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _manageMembers,
                                icon: const Icon(Icons.group_outlined),
                                label: Text(
                                  '${_group.memberCount} / ${_group.memberLimit} Üye',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => GroupChatScreen(
                                      apiService: widget.apiService,
                                      group: _group,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text('Grup Sohbeti'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Grup Etkinlikleri',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_group.isAdmin)
                      FilledButton.tonalIcon(
                        onPressed: _openCreateEvent,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Etkinlik Oluştur'),
                      ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<GroupEvent>>(
              future: _events,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: EcoShimmerList(itemCount: 3),
                  );
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: _SectionMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Etkinlikler yüklenemedi',
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    ),
                  );
                }
                final events = snapshot.data ?? const [];
                if (events.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _SectionMessage(
                      icon: Icons.event_available_outlined,
                      title: 'Henüz etkinlik yok',
                      message: _group.isAdmin
                          ? 'Grubun ilk etkinliğini oluşturabilirsin.'
                          : 'Yöneticiler yeni bir etkinlik planladığında burada görünecek.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                  sliver: SliverList.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _GroupEventCard(
                      apiService: widget.apiService,
                      group: _group,
                      event: events[index],
                      onChanged: _reload,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditGroupSheet extends StatefulWidget {
  const _EditGroupSheet({required this.apiService, required this.group});

  final ApiService apiService;
  final CommunityGroup group;

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _neighborhood;
  late final TextEditingController _memberLimit;
  late final TextEditingController _password;
  String? _city;
  String? _district;
  Uint8List? _cover;
  String? _coverName;
  bool _saving = false;
  late bool _privateGroup;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name);
    _description = TextEditingController(text: widget.group.description);
    _neighborhood = TextEditingController(text: widget.group.neighborhood);
    _memberLimit = TextEditingController(
      text: widget.group.memberLimit.toString(),
    );
    _password = TextEditingController();
    _city = TurkishLocations.provinces.containsKey(widget.group.city)
        ? widget.group.city
        : null;
    final districts = _city == null
        ? const <String>[]
        : TurkishLocations.districtsFor(_city!);
    _district = districts.contains(widget.group.district)
        ? widget.group.district
        : null;
    _privateGroup = widget.group.privateGroup;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _neighborhood.dispose();
    _memberLimit.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kapak görseli 5 MB altında olmalı.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _cover = bytes;
        _coverName = file.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.apiService.updateCommunityGroup(
        groupId: widget.group.id,
        name: _name.text,
        description: _description.text,
        city: _city!,
        district: _district!,
        neighborhood: _neighborhood.text,
        memberLimit: int.parse(_memberLimit.text),
        privateGroup: _privateGroup,
        joinCode: _privateGroup ? _password.text : null,
        coverBytes: _cover,
        coverFileName: _coverName,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EcoSheetHandle(),
              Text(
                'Grubu Düzenle',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCover,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _cover != null
                      ? Image.memory(_cover!, fit: BoxFit.cover)
                      : widget.group.coverImageUrl != null
                      ? Image.network(
                          widget.group.coverImageUrl!,
                          fit: BoxFit.cover,
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36),
                            Text('Grup görselini değiştir'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Grup adı'),
                validator: (value) =>
                    (value ?? '').trim().length < 3 ? 'En az 3 karakter' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _privateGroup,
                onChanged: (value) => setState(() {
                  _privateGroup = value;
                  if (!value) _password.clear();
                }),
                secondary: const Icon(Icons.lock_outline_rounded),
                title: const Text('Şifreli grup'),
                subtitle: const Text(
                  'Doğru şifreyi bilen kullanıcılar doğrudan katılır.',
                ),
              ),
              if (_privateGroup) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.group.privateGroup
                        ? 'Yeni şifre (değiştirmeyeceksen boş bırak)'
                        : 'Grup şifresi',
                    prefixIcon: const Icon(Icons.password_rounded),
                  ),
                  validator: (value) {
                    if (!_privateGroup || widget.group.privateGroup) {
                      return null;
                    }
                    return (value ?? '').trim().length < 4
                        ? 'Şifre en az 4 karakter olmalıdır'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Açıklama'),
                validator: (value) => (value ?? '').trim().length < 10
                    ? 'En az 10 karakter'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(
                  labelText: 'İl',
                  hintText: 'İl seçin',
                ),
                items: TurkishLocations.provinceNames
                    .map(
                      (city) =>
                          DropdownMenuItem(value: city, child: Text(city)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _city = value;
                  _district = null;
                }),
                validator: (value) =>
                    value == null ? 'Lütfen bir il seçin' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_city),
                initialValue: _district,
                decoration: const InputDecoration(
                  labelText: 'İlçe',
                  hintText: 'Önce il, sonra ilçe seçin',
                ),
                items: _city == null
                    ? const <DropdownMenuItem<String>>[]
                    : TurkishLocations.districtsFor(_city!)
                          .map(
                            (district) => DropdownMenuItem(
                              value: district,
                              child: Text(district),
                            ),
                          )
                          .toList(),
                onChanged: _city == null
                    ? null
                    : (value) => setState(() => _district = value),
                validator: (value) =>
                    value == null ? 'Lütfen bir ilçe seçin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _neighborhood,
                decoration: const InputDecoration(labelText: 'Mahalle'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memberLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Üye limiti'),
                validator: (value) {
                  final limit = int.tryParse(value ?? '');
                  return limit == null || limit < 2 || limit > 200
                      ? '2-200 arasında olmalı'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Değişiklikleri Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupEventCard extends StatelessWidget {
  const _GroupEventCard({
    required this.apiService,
    required this.group,
    required this.event,
    required this.onChanged,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final GroupEvent event;
  final VoidCallback onChanged;

  Future<void> _rsvp(BuildContext context, String status) async {
    try {
      await EcoHaptics.light();
      await apiService.updateGroupEventRsvp(
        groupId: group.id,
        eventId: event.id,
        status: status,
      );
      onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showAttendees(BuildContext context) async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) => FutureBuilder<List<EventMember>>(
        future: apiService.fetchGroupEventAttendees(
          groupId: group.id,
          eventId: event.id,
        ),
        builder: (context, snapshot) {
          final users = snapshot.data ?? const [];
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EcoSheetHandle(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Katılımcılar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const EcoShimmerList(itemCount: 3, padding: EdgeInsets.zero)
                else if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Henüz katılımcı yok.'),
                  )
                else
                  ...users.map((user) {
                    final friend = apiService.confirmedFriend(user.userId);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PrivacyAwareAvatar(
                        userId: user.userId,
                        currentUserId: apiService.currentUser?.id,
                        avatarLevel: user.avatarLevel,
                        highestAvatarLevel: user.highestAvatarLevel,
                        profileImagePreference: user.profileImagePreference,
                        adult: user.adult,
                        profileVisibility: user.profileVisibility,
                        profilePictureUrl:
                            user.profilePictureUrl ?? friend?.profilePictureUrl,
                        selectedAvatarPath:
                            user.selectedAvatarPath ??
                            friend?.selectedAvatarPath,
                        friendshipStatus:
                            user.friendshipStatus ??
                            (friend == null ? null : 'ACCEPTED'),
                      ),
                      title: Text(user.fullName),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Etkinlik silinsin mi?'),
        content: Text('${event.title} kalıcı olarak kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Etkinliği Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await apiService.deleteGroupEvent(groupId: group.id, eventId: event.id);
      onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: EdgeInsets.zero,
      tint: colors.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.coverImageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(
                event.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.event_available_rounded, size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (group.isAdmin ||
                        event.creatorId == apiService.currentUser?.id)
                      IconButton(
                        tooltip: 'Etkinliği sil',
                        onPressed: () => _delete(context),
                        icon: Icon(Icons.delete_outline, color: colors.error),
                      ),
                  ],
                ),
                Text(event.description, maxLines: 3),
                const SizedBox(height: 12),
                _EventInfo(
                  icon: Icons.schedule_outlined,
                  text: event.dateLabel,
                ),
                _EventInfo(
                  icon: Icons.location_on_outlined,
                  text:
                      '${event.exactAddress}, ${event.district}/${event.city}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: event.isAttending,
                      onSelected: (_) => _rsvp(context, 'ATTENDING'),
                      avatar: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Katılıyorum'),
                    ),
                    ChoiceChip(
                      selected: event.currentUserAttendance == 'NOT_ATTENDING',
                      onSelected: (_) => _rsvp(context, 'NOT_ATTENDING'),
                      avatar: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Katılamıyorum'),
                    ),
                    ActionChip(
                      onPressed: () => _showAttendees(context),
                      avatar: const Icon(Icons.people_outline, size: 18),
                      label: Text('${event.attendeeCount} katılımcı'),
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

class _EventInfo extends StatelessWidget {
  const _EventInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _RoleAwareMembersSheet extends StatefulWidget {
  const _RoleAwareMembersSheet({
    required this.apiService,
    required this.group,
    required this.onChanged,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final VoidCallback onChanged;

  @override
  State<_RoleAwareMembersSheet> createState() => _RoleAwareMembersSheetState();
}

class _RoleAwareMembersSheetState extends State<_RoleAwareMembersSheet> {
  final _username = TextEditingController();
  late Future<List<EventMember>> _members;
  late Future<List<GroupJoinRequest>> _requests;
  bool _adding = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _members = widget.apiService.fetchCommunityGroupMembers(widget.group.id);
      _requests = Future.value(const []);
    });
    widget.onChanged();
  }

  Future<void> _reviewRequest(GroupJoinRequest request, bool approve) async {
    try {
      await widget.apiService.reviewGroupJoinRequest(
        groupId: widget.group.id,
        requestId: request.id,
        approve: approve,
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addMember() async {
    final username = _username.text.trim();
    if (username.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await widget.apiService.addCommunityGroupMember(
        widget.group.id,
        username,
      );
      _username.clear();
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _action(EventMember member, String action) async {
    try {
      if (action == 'promote') {
        await widget.apiService.promoteCommunityGroupAdmin(
          widget.group.id,
          member.userId,
        );
      } else if (action == 'demote') {
        await widget.apiService.demoteCommunityGroupAdmin(
          widget.group.id,
          member.userId,
        );
      } else {
        await widget.apiService.removeCommunityGroupMember(
          widget.group.id,
          member.userId,
        );
      }
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  bool _canRemove(EventMember member) {
    if (member.isFounder) return false;
    return widget.group.isFounder;
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 1,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        children: [
          const EcoSheetHandle(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Grup Üyeleri',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'Bir üyeye dokunarak EcoVision profilini görüntüleyebilirsin.',
            ),
          ),
          TabBar(
            onTap: (index) => setState(() => _tabIndex = index),
            tabs: const [Tab(text: 'Üyeler')],
          ),
          const SizedBox(height: 10),
          if (_tabIndex == 0)
            Expanded(
              child: FutureBuilder<List<EventMember>>(
                future: _members,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const EcoShimmerList(itemCount: 5);
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final members = snapshot.data ?? const [];
                  return ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PublicProfileScreen(
                              apiService: widget.apiService,
                              userId: member.userId,
                            ),
                          ),
                        ),
                        leading: PrivacyAwareAvatar(
                          userId: member.userId,
                          currentUserId: widget.apiService.currentUser?.id,
                          avatarLevel: member.avatarLevel,
                          highestAvatarLevel: member.highestAvatarLevel,
                          profileImagePreference: member.profileImagePreference,
                          adult: member.adult,
                          profileVisibility: member.profileVisibility,
                          profilePictureUrl:
                              member.profilePictureUrl ??
                              widget.apiService
                                  .confirmedFriend(member.userId)
                                  ?.profilePictureUrl,
                          selectedAvatarPath:
                              member.selectedAvatarPath ??
                              widget.apiService
                                  .confirmedFriend(member.userId)
                                  ?.selectedAvatarPath,
                          friendshipStatus:
                              member.friendshipStatus ??
                              (widget.apiService.confirmedFriend(
                                        member.userId,
                                      ) ==
                                      null
                                  ? null
                                  : 'ACCEPTED'),
                        ),
                        title: Text(member.fullName),
                        subtitle: Text(
                          member.isFounder
                              ? 'Kurucu'
                              : member.isAdmin
                              ? 'Yönetici'
                              : 'Üye',
                        ),
                        trailing: member.isFounder
                            ? const Icon(Icons.workspace_premium_outlined)
                            : widget.group.isFounder
                            ? PopupMenuButton<String>(
                                onSelected: (value) => _action(member, value),
                                itemBuilder: (_) => [
                                  if (widget.group.isFounder && !member.isAdmin)
                                    const PopupMenuItem(
                                      value: 'promote',
                                      child: Text('Yönetici Yap'),
                                    ),
                                  if (widget.group.isFounder &&
                                      member.isAdmin &&
                                      !member.isFounder)
                                    const PopupMenuItem(
                                      value: 'demote',
                                      child: Text('Yöneticiliği Al'),
                                    ),
                                  if (_canRemove(member))
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text(
                                        'Gruptan Çıkar',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  );
                },
              ),
            ),
          if (_tabIndex == 1 && widget.group.isAdmin)
            Expanded(
              child: FutureBuilder<List<GroupJoinRequest>>(
                future: _requests,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const EcoShimmerList(itemCount: 4);
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 48),
                            SizedBox(height: 10),
                            Text('Bekleyen katılım isteği yok.'),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return ListTile(
                        leading: PrivacyAwareAvatar(
                          userId: request.userId,
                          currentUserId: widget.apiService.currentUser?.id,
                          avatarLevel: request.avatarLevel,
                          highestAvatarLevel: request.highestAvatarLevel,
                          profileImagePreference:
                              request.profileImagePreference,
                          adult: request.adult,
                          profileVisibility: request.profileVisibility,
                          profilePictureUrl:
                              request.profilePictureUrl ??
                              widget.apiService
                                  .confirmedFriend(request.userId)
                                  ?.profilePictureUrl,
                          selectedAvatarPath:
                              request.selectedAvatarPath ??
                              widget.apiService
                                  .confirmedFriend(request.userId)
                                  ?.selectedAvatarPath,
                          friendshipStatus:
                              widget.apiService.confirmedFriend(
                                    request.userId,
                                  ) ==
                                  null
                              ? null
                              : 'ACCEPTED',
                        ),
                        title: Text(request.fullName),
                        subtitle: Text('@${request.username}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Reddet',
                              onPressed: () => _reviewRequest(request, false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                            IconButton.filled(
                              tooltip: 'Onayla',
                              onPressed: () => _reviewRequest(request, true),
                              icon: const Icon(Icons.check_rounded),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _MembersSheet extends StatelessWidget {
  const _MembersSheet({
    required this.apiService,
    required this.group,
    required this.members,
    required this.onChanged,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final Future<List<EventMember>> members;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final currentUserId = apiService.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        children: [
          const EcoSheetHandle(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Grup Üyeleri',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<EventMember>>(
              future: members,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EcoShimmerList(itemCount: 5);
                }
                final users = snapshot.data ?? const [];
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final friend = apiService.confirmedFriend(user.userId);
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PublicProfileScreen(
                            apiService: apiService,
                            userId: user.userId,
                          ),
                        ),
                      ),
                      leading: PrivacyAwareAvatar(
                        userId: user.userId,
                        currentUserId: currentUserId,
                        avatarLevel: user.avatarLevel,
                        highestAvatarLevel: user.highestAvatarLevel,
                        profileImagePreference: user.profileImagePreference,
                        adult: user.adult,
                        profileVisibility: user.profileVisibility,
                        profilePictureUrl:
                            user.profilePictureUrl ?? friend?.profilePictureUrl,
                        selectedAvatarPath:
                            user.selectedAvatarPath ??
                            friend?.selectedAvatarPath,
                        friendshipStatus:
                            user.friendshipStatus ??
                            (friend == null ? null : 'ACCEPTED'),
                      ),
                      title: Text(user.fullName),
                      subtitle: Text(user.isAdmin ? 'Grup yöneticisi' : 'Üye'),
                      trailing:
                          group.isAdmin &&
                              user.userId != currentUserId &&
                              user.userId != group.creatorId
                          ? PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'admin') {
                                  await apiService.promoteCommunityGroupAdmin(
                                    group.id,
                                    user.userId,
                                  );
                                } else {
                                  await apiService.removeCommunityGroupMember(
                                    group.id,
                                    user.userId,
                                  );
                                }
                                onChanged();
                                if (context.mounted) Navigator.pop(context);
                              },
                              itemBuilder: (_) => [
                                if (!user.isAdmin)
                                  const PopupMenuItem(
                                    value: 'admin',
                                    child: Text('Yönetici Yap'),
                                  ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    'Gruptan Çıkar',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : user.isAdmin
                          ? const Icon(Icons.verified_user_outlined)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CreateGroupEventSheet extends StatefulWidget {
  const CreateGroupEventSheet({
    required this.apiService,
    required this.group,
    required this.onCreated,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final VoidCallback onCreated;

  @override
  State<CreateGroupEventSheet> createState() => _CreateGroupEventSheetState();
}

class _CreateGroupEventSheetState extends State<CreateGroupEventSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  final _picker = ImagePicker();
  String? _city;
  String? _district;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  Uint8List? _cover;
  String? _coverName;
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) return;
    if (mounted) {
      setState(() {
        _cover = bytes;
        _coverName = image.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final location = await LocationService().getCurrentEventLocation();
      if (!mounted) return;
      String? city;
      for (final item in TurkishLocations.provinceNames) {
        if (item.toLowerCase() == location.city.toLowerCase()) {
          city = item;
          break;
        }
      }
      if (city != null) {
        _city = city;
        final districts = TurkishLocations.districtsFor(city);
        String? district;
        for (final item in districts) {
          if (item.toLowerCase() == location.district.toLowerCase()) {
            district = item;
            break;
          }
        }
        _district = district;
      }
      _address.text = location.address;
      setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_date.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Etkinlik tarihi gelecekte olmalıdır.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiService.createGroupEvent(
        groupId: widget.group.id,
        title: _title.text,
        description: _description.text,
        eventDate: _date,
        city: _city!,
        district: _district!,
        exactAddress: _address.text,
        capacity: int.tryParse(_capacity.text) ?? 20,
        coverBytes: _cover,
        coverFileName: _coverName,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('ApiException: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EcoSheetHandle(),
            Text(
              'Grup Etkinliği Oluştur',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _cover == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36),
                          Text('Kapak fotoğrafı ekle'),
                        ],
                      )
                    : Image.memory(_cover!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Etkinlik adı'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Etkinlik adı gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              validator: (value) => (value ?? '').trim().length < 10
                  ? 'Açıklama en az 10 karakter olmalı'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Tarih ve saat'),
              subtitle: Text(
                '${_date.day}.${_date.month}.${_date.year} '
                '${_date.hour.toString().padLeft(2, '0')}:'
                '${_date.minute.toString().padLeft(2, '0')}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Seç'),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'İl',
                hintText: 'İl seçin',
              ),
              items: TurkishLocations.provinceNames
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _city = value;
                _district = null;
              }),
              validator: (value) =>
                  value == null ? 'Lütfen bir il seçin' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_city),
              initialValue: _district,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'İlçe',
                hintText: 'Önce il, sonra ilçe seçin',
              ),
              items: _city == null
                  ? const <DropdownMenuItem<String>>[]
                  : TurkishLocations.districtsFor(_city!)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
              onChanged: _city == null
                  ? null
                  : (value) => setState(() => _district = value),
              validator: (value) =>
                  value == null ? 'Lütfen bir ilçe seçin' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Buluşma adresi',
                prefixIcon: const Icon(Icons.pin_drop_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Mevcut konumumu kullan',
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
              validator: (value) => (value ?? '').trim().length < 8
                  ? 'Açık adres en az 8 karakter olmalı'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kontenjan',
                prefixIcon: Icon(Icons.people_alt_outlined),
              ),
              validator: (value) {
                final number = int.tryParse(value ?? '');
                return number == null || number < 2 || number > 500
                    ? 'Kontenjan 2 ile 500 arasında olmalı'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available_outlined),
                label: const Text('Etkinliği Yayınla'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ],
    ),
  );
}
