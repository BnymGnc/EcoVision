import 'dart:async';

import 'package:flutter/material.dart';

import '../core/turkey_locations.dart';
import '../models/cleanup_event.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import 'event_chat_screen.dart';
import 'public_profile_screen.dart';
import '../widgets/notification_bell.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    required this.apiService,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });
  final ApiService apiService;
  final int notificationCount;
  final VoidCallback? onNotifications;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<CleanupEvent>> _groups;
  late Future<List<SocialUser>> _friends;
  late Future<List<FriendRequest>> _requests;
  late Future<List<GroupInviteModel>> _invites;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() => setState(() {
    _groups = widget.apiService.fetchEvents(query: _search.text);
    _friends = widget.apiService.fetchFriends();
    _requests = widget.apiService.fetchFriendRequests();
    _invites = widget.apiService.fetchGroupInvites();
  });

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  Future<void> _join(CleanupEvent event) async {
    String? code;
    if (event.privateGroup && !event.isJoined) {
      final controller = TextEditingController();
      code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Özel gruba katıl'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Grup parolası',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Katıl'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (code == null) return;
    }
    try {
      final joined = event.isJoined
          ? event
          : await widget.apiService.joinEvent(event.id, joinCode: code);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<bool>(
          builder: (_) =>
              EventChatScreen(apiService: widget.apiService, event: joined),
        ),
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluk'),
        actions: [
          if (widget.onNotifications != null)
            NotificationBell(
              count: widget.notificationCount,
              onPressed: widget.onNotifications!,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Gruplar'),
            Tab(text: 'Arkadaşlar'),
            Tab(text: 'Davetler'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGroup(),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Grup Kur'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_groupsTab(), _friendsTab(), _invitesTab()],
      ),
    );
  }

  Widget _groupsTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'Şehrindeki grupları ara',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<CleanupEvent>>(
          future: _groups,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const _Loading();
            if (snapshot.hasError)
              return _Empty(
                icon: Icons.cloud_off_outlined,
                title: 'Gruplar yüklenemedi',
                message: snapshot.error.toString(),
                action: _reload,
              );
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty)
              return _Empty(
                icon: Icons.groups_outlined,
                title: 'Şehrinde grup bulunamadı',
                message:
                    'Aramana uygun bir grup yok. İlk grubu sen kurabilirsin.',
                action: _openCreateGroup,
              );
            return Column(
              children: groups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GroupCard(
                        group: group,
                        onTap: () => _join(group),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _friendsTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const _SectionTitle('Arkadaşlık İstekleri'),
        FutureBuilder<List<FriendRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            final requests = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting)
              return const LinearProgressIndicator();
            if (requests.isEmpty)
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('Bekleyen arkadaşlık isteğin yok.'),
              );
            return Column(
              children: requests
                  .map(
                    (request) => ListTile(
                      leading: _Avatar(user: request.requester),
                      title: Text(request.requester.fullName),
                      subtitle: Text(request.requester.city),
                      trailing: FilledButton(
                        onPressed: () async {
                          try {
                            await widget.apiService.acceptFriendRequest(
                              request.id,
                            );
                            _reload();
                          } catch (e) {
                            _showError(e);
                          }
                        },
                        child: const Text('Kabul Et'),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const Divider(height: 32),
        const _SectionTitle('Arkadaşlarım'),
        FutureBuilder<List<SocialUser>>(
          future: _friends,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const _Loading();
            final friends = snapshot.data ?? const [];
            if (friends.isEmpty)
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Henüz arkadaşın yok. Liderlik tablosundan yeni kahramanlar keşfet.',
                ),
              );
            return Column(
              children: friends
                  .map(
                    (friend) => ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PublicProfileScreen(
                            apiService: widget.apiService,
                            userId: friend.id,
                          ),
                        ),
                      ),
                      leading: _Avatar(user: friend),
                      title: Text(friend.fullName),
                      subtitle: Text(
                        '${friend.city} • Avatar ${friend.avatarLevel}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _invitesTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: FutureBuilder<List<GroupInviteModel>>(
      future: _invites,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const _Loading();
        if (snapshot.hasError)
          return _Empty(
            icon: Icons.error_outline,
            title: 'Davetler yüklenemedi',
            message: snapshot.error.toString(),
            action: _reload,
          );
        final invites = snapshot.data ?? const [];
        if (invites.isEmpty)
          return const _Empty(
            icon: Icons.mark_email_read_outlined,
            title: 'Yeni davet yok',
            message: 'Özel grup davetlerin burada görünecek.',
          );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: invites
              .map(
                (invite) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.eventTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text('${invite.inviter.fullName} seni davet etti'),
                        Text(invite.location),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              await widget.apiService.acceptGroupInvite(
                                invite.id,
                              );
                              _reload();
                            } catch (e) {
                              _showError(e);
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Daveti Kabul Et'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );

  void _openCreateGroup() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _CreateGroupSheet(apiService: widget.apiService, onCreated: _reload),
  );
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.apiService, required this.onCreated});
  final ApiService apiService;
  final VoidCallback onCreated;
  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  late String _city;
  late String _district;
  late String _neighborhood;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  int _limit = 20;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _city = ecoLocations.keys.first;
    _resetDistrict();
  }

  void _resetDistrict() {
    _district = ecoLocations[_city]!.keys.first;
    _neighborhood = ecoLocations[_city]![_district]!.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null)
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.apiService.createCleanupEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        city: _city,
        district: _district,
        neighborhood: _neighborhood,
        eventDate: _date,
        memberLimit: _limit,
        joinCode: _code.text.trim(),
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
            Text(
              'Yeni Temizlik Grubu',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Grup adı',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Grup adı gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Amaç ve açıklama'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'İl'),
              items: ecoLocations.keys
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() {
                _city = v!;
                _resetDistrict();
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _district,
              key: ValueKey('d$_city'),
              decoration: const InputDecoration(labelText: 'İlçe'),
              items: ecoLocations[_city]!.keys
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() {
                _district = v!;
                _neighborhood = ecoLocations[_city]![_district]!.first;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _neighborhood,
              key: ValueKey('n$_city$_district'),
              decoration: const InputDecoration(labelText: 'Mahalle'),
              items: ecoLocations[_city]![_district]!
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _neighborhood = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Buluşma zamanı'),
              subtitle: Text(
                '${_date.day}.${_date.month}.${_date.year} ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Değiştir'),
              ),
            ),
            Row(
              children: [
                const Expanded(child: Text('Üye sınırı')),
                DropdownButton<int>(
                  value: _limit,
                  items: [10, 20, 50, 100]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v kişi')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _limit = v!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _code,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Katılım parolası (isteğe bağlı)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
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
                    : const Icon(Icons.add),
                label: const Text('Grubu Oluştur'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});
  final CleanupEvent group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    group.privateGroup
                        ? Icons.lock_outline
                        : Icons.eco_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(group.location),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('${group.memberCount}/${group.memberLimit} üye'),
                ),
                Chip(label: Text(group.dateLabel)),
                if (group.isJoined)
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 17),
                    label: Text('Üyesin'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final SocialUser user;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundImage: user.profilePictureUrl == null
        ? null
        : NetworkImage(user.profilePictureUrl!),
    child: user.profilePictureUrl == null
        ? Text(user.fullName.isEmpty ? 'E' : user.fullName[0])
        : null,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: action,
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
          ),
        ],
      ],
    ),
  );
}
