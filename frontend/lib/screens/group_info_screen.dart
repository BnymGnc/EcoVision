import 'package:flutter/material.dart';

import '../models/cleanup_event.dart';
import '../models/event_member.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import 'public_profile_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    required this.apiService,
    required this.event,
    super.key,
  });
  final ApiService apiService;
  final CleanupEvent event;
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late Future<List<EventMember>> _members;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(
    () => _members = widget.apiService.fetchEventMembers(widget.event.id),
  );
  void _error(Object e) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(e.toString())));
  Future<void> _invite() async {
    try {
      final friends = await widget.apiService.fetchFriends();
      if (!mounted) return;
      final friend = await showModalBottomSheet<SocialUser>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const ListTile(
                title: Text(
                  'Arkadaşını Davet Et',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (friends.isEmpty)
                const ListTile(
                  title: Text('Davet edebileceğin arkadaşın yok.'),
                ),
              ...friends.map(
                (f) => ListTile(
                  leading: CircleAvatar(
                    child: Text(f.fullName.isEmpty ? 'E' : f.fullName[0]),
                  ),
                  title: Text(f.fullName),
                  subtitle: Text(f.city),
                  onTap: () => Navigator.pop(context, f),
                ),
              ),
            ],
          ),
        ),
      );
      if (friend != null) {
        await widget.apiService.inviteFriendToGroup(widget.event.id, friend.id);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Özel grup daveti gönderildi.')),
          );
      }
    } catch (e) {
      if (mounted) _error(e);
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Spam', 'Uygunsuz içerik', 'Yanıltıcı grup']
              .map(
                (r) => ListTile(
                  title: Text(r),
                  onTap: () => Navigator.pop(context, r),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (reason != null) {
      try {
        await widget.apiService.reportGroup(widget.event.id, reason);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grup bildirimin alındı.')),
          );
      } catch (e) {
        if (mounted) _error(e);
      }
    }
  }

  Future<void> _removeMember(EventMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Gruptan Çıkar'),
        content: Text(
          '${member.fullName} bu grubun sohbetine ve etkinliklerine erişemeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Üyeyi Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.removeEventMember(
        widget.event.id,
        member.userId,
      );
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.fullName} gruptan çıkarıldı.')),
        );
      }
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Grup Bilgisi'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'report') _report();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'report',
              child: ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text('Grubu Bildir'),
              ),
            ),
          ],
        ),
      ],
    ),
    body: FutureBuilder<List<EventMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          );
        final members = snapshot.data ?? const [];
        final admins = members.where((m) => m.isAdmin).toList();
        final regular = members.where((m) => !m.isAdmin).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 46,
                child: Text(
                  widget.event.title.isEmpty
                      ? 'EV'
                      : widget.event.title.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.event.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(widget.event.location, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '${widget.event.memberCount}/${widget.event.memberLimit} üye • ${widget.event.privateGroup ? 'Özel grup' : 'Açık grup'}',
              textAlign: TextAlign.center,
            ),
            if (widget.event.isAdmin && widget.event.privateGroup) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Arkadaş Davet Et'),
              ),
            ],
            const SizedBox(height: 24),
            _title(context, 'Yöneticiler'),
            ...admins.map((m) => _member(m)),
            const SizedBox(height: 14),
            _title(context, 'Üyeler'),
            ...regular.map((m) => _member(m)),
          ],
        );
      },
    ),
  );
  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
  Widget _member(EventMember member) => ListTile(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          apiService: widget.apiService,
          userId: member.userId,
        ),
      ),
    ),
    leading: CircleAvatar(
      backgroundImage: member.profilePictureUrl == null
          ? null
          : NetworkImage(member.profilePictureUrl!),
      child: member.profilePictureUrl == null
          ? Text('${member.avatarLevel}')
          : null,
    ),
    title: Text(member.fullName),
    subtitle: Text(member.isAdmin ? 'Yönetici' : 'Üye'),
    trailing:
        widget.event.isAdmin &&
            member.userId != widget.apiService.currentUser?.id
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!member.isAdmin)
                IconButton(
                  tooltip: 'Grup yöneticisi yap',
                  onPressed: () async {
                    try {
                      await widget.apiService.promoteEventAdmin(
                        widget.event.id,
                        member.userId,
                      );
                      _reload();
                    } catch (error) {
                      _error(error);
                    }
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                ),
              IconButton(
                tooltip: 'Üyeyi gruptan çıkar',
                onPressed: () => _removeMember(member),
                color: Theme.of(context).colorScheme.error,
                icon: const Icon(Icons.person_remove_outlined),
              ),
            ],
          )
        : const Icon(Icons.chevron_right),
  );
}
