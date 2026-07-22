import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/moderation_report.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class SuperuserDashboardScreen extends StatefulWidget {
  const SuperuserDashboardScreen({required this.apiService, super.key});
  final ApiService apiService;
  @override
  State<SuperuserDashboardScreen> createState() =>
      _SuperuserDashboardScreenState();
}

class _SuperuserDashboardScreenState extends State<SuperuserDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<ModerationReport>> _reports;
  late Future<List<UserProfile>> _users;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _reports = widget.apiService.fetchModerationReports();
    _users = widget.apiService.fetchAdminUsers();
  });
  void _message(Object value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value.toString())));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      title: const Text(
        'Superuser Dashboard',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Raporlar'),
          Tab(text: 'Yayın'),
          Tab(text: 'Kullanıcılar'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [_reportsTab(), _broadcastTab(), _usersTab()],
    ),
  );
  Widget _reportsTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: FutureBuilder<List<ModerationReport>>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(message: snapshot.error.toString(), retry: _reload);
        final reports = snapshot.data ?? const [];
        if (reports.isEmpty)
          return const _Empty(
            icon: Icons.verified_user_outlined,
            title: 'Moderasyon kuyruğu temiz',
            message: 'Yeni kullanıcı ve grup bildirimleri burada görünür.',
          );
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ReportCard(
            report: reports[index],
            onAudit: () => _audit(reports[index]),
            onAction: () => _moderate(reports[index]),
          ),
        );
      },
    ),
  );
  Future<void> _audit(ModerationReport report) async {
    try {
      final messages = report.isGroup
          ? await widget.apiService.auditGroupChat(report.groupId!)
          : await widget.apiService.auditUserChat(report.reportedUserId!);
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _AuditScreen(
              title: report.isGroup
                  ? report.groupTitle ?? 'Grup Denetimi'
                  : report.reportedUserName ?? 'Kullanıcı Denetimi',
              messages: messages,
            ),
          ),
        );
    } catch (e) {
      if (mounted) _message(e);
    }
  }

  Future<void> _moderate(ModerationReport report) async {
    if (report.isGroup) {
      final ok = await _confirm('Grup kalıcı olarak silinsin mi?');
      if (ok) {
        try {
          await widget.apiService.superuserDeleteGroup(report.groupId!);
          _message('Grup silindi.');
          _reload();
        } catch (e) {
          _message(e);
        }
      }
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Kullanıcıyı Yasakla'),
              onTap: () => Navigator.pop(context, 'ban'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('7 Gün Askıya Al'),
              onTap: () => Navigator.pop(context, 'suspend'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Yasağı Kaldır'),
              onTap: () => Navigator.pop(context, 'unban'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'ban')
        await widget.apiService.banUser(report.reportedUserId!);
      if (action == 'suspend')
        await widget.apiService.suspendUser(report.reportedUserId!, 7);
      if (action == 'unban')
        await widget.apiService.unbanUser(report.reportedUserId!);
      _message('Moderasyon işlemi uygulandı.');
      _reload();
    } catch (e) {
      _message(e);
    }
  }

  Future<void> _moderateUser(UserProfile user, String action) async {
    try {
      if (action == 'ban') {
        final confirmed = await _confirm(
          '${user.fullName} kalıcı olarak yasaklansın mı?',
        );
        if (!confirmed) return;
        await widget.apiService.banUser(user.id);
      } else if (action == 'suspend') {
        await widget.apiService.suspendUser(user.id, 7);
      } else if (action == 'unban') {
        await widget.apiService.unbanUser(user.id);
      }
      if (!mounted) return;
      _message('Moderasyon işlemi uygulandı.');
      _reload();
    } catch (e) {
      if (mounted) _message(e);
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Onay Gerekli'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;
  Widget _broadcastTab() => _BroadcastForm(
    apiService: widget.apiService,
    onSent: (count) => _message('$count kullanıcıya bildirim gönderildi.'),
  );
  Widget _usersTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: FutureBuilder<List<UserProfile>>(
      future: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(message: snapshot.error.toString(), retry: _reload);
        final users = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AssignAdmin(apiService: widget.apiService, onDone: _reload),
            const SizedBox(height: 18),
            Text(
              '${users.length} Kullanıcı',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...users.map(
              (user) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profilePictureUrl == null
                        ? null
                        : NetworkImage(user.profilePictureUrl!),
                    child: user.profilePictureUrl == null
                        ? Text(user.name.isEmpty ? 'E' : user.name[0])
                        : null,
                  ),
                  title: Text(user.fullName),
                  subtitle: Text(
                    '${user.email}\n${user.role} • ${user.totalPoints} puan${user.banned
                        ? ' • Yasaklı'
                        : user.suspendedUntil != null
                        ? ' • Askıda'
                        : ''}',
                  ),
                  isThreeLine: true,
                  trailing:
                      user.isSuperuser ||
                          user.id == widget.apiService.currentUser?.id
                      ? const Icon(Icons.verified_user_outlined)
                      : PopupMenuButton<String>(
                          tooltip: 'Moderasyon işlemleri',
                          onSelected: (action) => _moderateUser(user, action),
                          itemBuilder: (context) => [
                            if (!user.banned)
                              const PopupMenuItem(
                                value: 'ban',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.block, color: Colors.red),
                                  title: Text('Kullanıcıyı Yasakla'),
                                ),
                              ),
                            if (!user.banned)
                              const PopupMenuItem(
                                value: 'suspend',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.timer_outlined),
                                  title: Text('7 Gün Askıya Al'),
                                ),
                              ),
                            if (user.banned || user.suspendedUntil != null)
                              const PopupMenuItem(
                                value: 'unban',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.lock_open),
                                  title: Text('Erişimi Geri Aç'),
                                ),
                              ),
                          ],
                          icon: const Icon(Icons.more_vert),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onAudit,
    required this.onAction,
  });
  final ModerationReport report;
  final VoidCallback onAudit, onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                report.isGroup
                    ? Icons.groups_outlined
                    : Icons.person_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.isGroup
                      ? report.groupTitle ?? 'Bildirilen Grup'
                      : report.reportedUserName ?? 'Bildirilen Kullanıcı',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Chip(label: Text(report.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.reason,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (report.details?.isNotEmpty ?? false) Text(report.details!),
          const SizedBox(height: 5),
          Text(
            'Bildiren: ${report.reporterName}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAudit,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Sohbeti Denetle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(
                    report.isGroup
                        ? Icons.delete_outline
                        : Icons.gavel_outlined,
                  ),
                  label: Text(report.isGroup ? 'Grubu Sil' : 'İşlem Yap'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BroadcastForm extends StatefulWidget {
  const _BroadcastForm({required this.apiService, required this.onSent});
  final ApiService apiService;
  final ValueChanged<int> onSent;
  @override
  State<_BroadcastForm> createState() => _BroadcastFormState();
}

class _BroadcastFormState extends State<_BroadcastForm> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.campaign_rounded, size: 64, color: Colors.red),
      Text(
        'Global Bildirim Yayını',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _title,
        decoration: const InputDecoration(
          labelText: 'Başlık',
          prefixIcon: Icon(Icons.title),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _message,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Mesaj',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _sending
            ? null
            : () async {
                if (_title.text.trim().isEmpty || _message.text.trim().isEmpty)
                  return;
                setState(() => _sending = true);
                try {
                  final count = await widget.apiService.sendGlobalBroadcast(
                    title: _title.text,
                    message: _message.text,
                  );
                  widget.onSent(count);
                  _title.clear();
                  _message.clear();
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  if (mounted) setState(() => _sending = false);
                }
              },
        icon: _sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: const Text('Tüm Kullanıcılara Gönder'),
      ),
    ],
  );
}

class _AssignAdmin extends StatefulWidget {
  const _AssignAdmin({required this.apiService, required this.onDone});
  final ApiService apiService;
  final VoidCallback onDone;
  @override
  State<_AssignAdmin> createState() => _AssignAdminState();
}

class _AssignAdminState extends State<_AssignAdmin> {
  final _email = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Platform Yöneticisi Ata',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Kullanıcı e-postası'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.apiService.assignAdminRole(_email.text);
                      widget.onDone();
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Yönetici rolü atandı.'),
                          ),
                        );
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Yönetici Yap'),
          ),
        ],
      ),
    ),
  );
}

class _AuditScreen extends StatelessWidget {
  const _AuditScreen({required this.title, required this.messages});
  final String title;
  final List<ChatMessage> messages;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: messages.isEmpty
        ? const _Empty(
            icon: Icons.forum_outlined,
            title: 'Sohbet kaydı yok',
            message: 'Denetlenecek mesaj bulunamadı.',
          )
        : ListView.separated(
            reverse: false,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = messages[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(m.senderName.isEmpty ? 'E' : m.senderName[0]),
                  ),
                  title: Text(
                    m.senderName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.message.isNotEmpty) Text(m.message),
                      if (m.imageUrl != null)
                        Text(
                          'Fotoğraf: ${m.imageUrl}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        'Grup #${m.eventId} • ${m.timestamp.toLocal()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 62),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.tonalIcon(
      onPressed: retry,
      icon: const Icon(Icons.refresh),
      label: Text(message),
    ),
  );
}
