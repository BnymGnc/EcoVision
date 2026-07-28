import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../models/community_group.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import 'group_details_screen.dart';
import 'public_profile_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    required this.apiService,
    required this.group,
    super.key,
  });

  final ApiService apiService;
  final CommunityGroup group;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const _pageSize = 50;

  final _message = TextEditingController();
  final _scroll = ScrollController();
  late CommunityGroup _group;
  List<ChatMessage> _messages = const [];
  Map<int, GroupEvent> _events = const {};
  Timer? _poller;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _sending = false;
  int _historyOffset = 0;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _scroll.addListener(_onScroll);
    _loadInitial();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _message.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.offset < 100) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadInitial() async {
    try {
      final result = await Future.wait<Object>([
        widget.apiService.fetchCommunityGroup(_group.id),
        widget.apiService.fetchGroupMessages(_group.id, limit: _pageSize),
        widget.apiService.fetchGroupEvents(_group.id),
      ]);
      if (!mounted) return;
      final messages = result[1] as List<ChatMessage>;
      setState(() {
        _group = result[0] as CommunityGroup;
        _messages = messages;
        _historyOffset = messages.length;
        _events = {
          for (final event in result[2] as List<GroupEvent>) event.id: event,
        };
        _hasMore = messages.length == _pageSize;
        _loading = false;
      });
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _loading) return;
    _loadingOlder = true;
    try {
      final before = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0;
      final older = await widget.apiService.fetchGroupMessages(
        _group.id,
        limit: _pageSize,
        offset: _historyOffset,
      );
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(older, _messages);
        _historyOffset += older.length;
        _hasMore = older.length == _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final addedExtent = _scroll.position.maxScrollExtent - before;
        _scroll.jumpTo(
          (_scroll.offset + addedExtent)
              .clamp(0, _scroll.position.maxScrollExtent)
              .toDouble(),
        );
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _poll({bool forceMetadata = false}) async {
    if (_loading || _sending || !mounted) return;
    try {
      final nearBottom =
          !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.offset < 180;
      _pollCount++;
      final refreshMetadata = forceMetadata || _pollCount % 6 == 0;
      final messages = await widget.apiService.fetchGroupMessages(
        _group.id,
        limit: _pageSize,
      );
      CommunityGroup? refreshedGroup;
      List<GroupEvent>? refreshedEvents;
      if (refreshMetadata) {
        final metadata = await Future.wait<Object>([
          widget.apiService.fetchCommunityGroup(_group.id),
          widget.apiService.fetchGroupEvents(_group.id),
        ]);
        refreshedGroup = metadata[0] as CommunityGroup;
        refreshedEvents = metadata[1] as List<GroupEvent>;
      }
      if (!mounted) return;
      setState(() {
        if (refreshedGroup != null) _group = refreshedGroup;
        _messages = _mergeMessages(_messages, messages);
        if (refreshedEvents != null) {
          _events = {for (final event in refreshedEvents) event.id: event};
        }
      });
      if (nearBottom) _scrollToBottom();
    } catch (_) {
      // Polling failures are retried without interrupting the chat.
    }
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> first,
    List<ChatMessage> second,
  ) {
    final byId = <int, ChatMessage>{
      for (final item in first) item.id: item,
      for (final item in second) item.id: item,
    };
    final result = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    await EcoHaptics.light();
    setState(() => _sending = true);
    try {
      final sent = await widget.apiService.sendGroupMessage(
        groupId: _group.id,
        message: text,
      );
      _message.clear();
      if (!mounted) return;
      setState(() => _messages = _mergeMessages(_messages, [sent]));
      _scrollToBottom();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    await EcoHaptics.light();
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = selection?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > 2 * 1024 * 1024) {
      _showError('Fotoğraf ve PDF dosyaları 2 MB altında olmalıdır.');
      return;
    }
    setState(() => _sending = true);
    try {
      final contentType = switch (file.extension?.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'image/jpeg',
      };
      final sent = await widget.apiService.sendGroupChatAttachment(
        groupId: _group.id,
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _messages = _mergeMessages(_messages, [sent]));
      _scrollToBottom();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openGroupInfo() async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            GroupDetailsScreen(apiService: widget.apiService, group: _group),
      ),
    );
    if (!mounted) return;
    if (deleted == true) {
      Navigator.pop(context, true);
      return;
    }
    await _poll(forceMetadata: true);
  }

  Future<void> _createEvent() async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (_) => CreateGroupEventSheet(
        apiService: widget.apiService,
        group: _group,
        onCreated: () => _poll(forceMetadata: true),
      ),
    );
  }

  Future<void> _pinMessage(ChatMessage message) async {
    if (!_group.isAdmin) return;
    await EcoHaptics.selection();
    try {
      final updated = await widget.apiService.pinGroupContent(
        groupId: _group.id,
        type: 'MESSAGE',
        id: message.id,
      );
      if (mounted) setState(() => _group = updated);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _pinEvent(GroupEvent event) async {
    try {
      final updated = await widget.apiService.pinGroupContent(
        groupId: _group.id,
        type: 'EVENT',
        id: event.id,
      );
      if (mounted) setState(() => _group = updated);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _unpin() async {
    try {
      final updated = await widget.apiService.pinGroupContent(
        groupId: _group.id,
        type: 'NONE',
      );
      if (mounted) setState(() => _group = updated);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _openProfile(int userId) async {
    final pageContext = context;
    await showEcoGlassSheet<void>(
      context: context,
      builder: (sheetContext) => FutureBuilder<PublicProfile>(
        future: widget.apiService.fetchPublicProfile(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 360, child: EcoChatShimmer());
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 260,
              child: Center(child: Text(snapshot.error.toString())),
            );
          }
          final profile = snapshot.requireData;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EcoSheetHandle(),
                CircleAvatar(
                  radius: 46,
                  backgroundImage: profile.profilePictureUrl == null
                      ? null
                      : NetworkImage(profile.profilePictureUrl!),
                  child: profile.profilePictureUrl == null
                      ? const Icon(Icons.person_rounded, size: 42)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text('@${profile.username} • ${profile.city}'),
                const SizedBox(height: 16),
                if (profile.detailsVisible)
                  Wrap(
                    spacing: 10,
                    children: [
                      Chip(label: Text('Seviye ${profile.avatarLevel}')),
                      Chip(label: Text('${profile.totalPoints} Eco Puan')),
                      Chip(label: Text('${profile.likeCount} beğeni')),
                    ],
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Bu profil gizlidir.'),
                    subtitle: Text(
                      'Detayları görmek için arkadaşlık isteği gönderin.',
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        pageContext,
                        MaterialPageRoute<void>(
                          builder: (_) => PublicProfileScreen(
                            apiService: widget.apiService,
                            userId: userId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Profili Aç'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _replaceEvent(GroupEvent event) {
    setState(() => _events = {..._events, event.id: event});
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.apiService.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openGroupInfo,
          child: Row(
            children: [
              _GroupAvatar(group: _group),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_group.name, overflow: TextOverflow.ellipsis),
                    Text(
                      '${_group.memberCount} üye • ${_group.locationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_group.isAdmin)
            IconButton(
              tooltip: 'Etkinlik oluştur',
              onPressed: _createEvent,
              icon: const Icon(Icons.event_available_outlined),
            ),
          IconButton(
            tooltip: 'Grup bilgileri',
            onPressed: _openGroupInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_group.pinnedMessageId != null || _group.pinnedEventId != null)
            _PinnedBanner(
              group: _group,
              event: _events[_group.pinnedEventId],
              canUnpin: _group.isAdmin,
              onUnpin: _unpin,
            ),
          Expanded(
            child: _loading
                ? const EcoChatShimmer()
                : _messages.isEmpty
                ? const _ChatEmpty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loadingOlder && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final messageIndex = index - (_loadingOlder ? 1 : 0);
                      final item = _messages[messageIndex];
                      final event = item.groupEventId == null
                          ? null
                          : _events[item.groupEventId];
                      if (item.messageType == 'SYSTEM_EVENT' && event != null) {
                        return _ChatEventCard(
                          apiService: widget.apiService,
                          group: _group,
                          event: event,
                          onChanged: _replaceEvent,
                          onPin: _group.isAdmin ? () => _pinEvent(event) : null,
                        );
                      }
                      return _MessageBubble(
                        message: item,
                        mine: item.senderId == currentUserId,
                        onAvatarTap: item.senderId <= 0
                            ? null
                            : () => _openProfile(item.senderId),
                        onLongPress: _group.isAdmin && !item.isSystem
                            ? () => _pinMessage(item)
                            : null,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Fotoğraf veya PDF ekle',
                    onPressed: _sending ? null : _attach,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Mesaj yaz...',
                        prefixIcon: Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    tooltip: 'Gönder',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.group});

  final CommunityGroup group;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundImage: group.coverImageUrl == null
        ? null
        : NetworkImage(group.coverImageUrl!),
    child: group.coverImageUrl == null
        ? const Icon(Icons.groups_2_outlined)
        : null,
  );
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({
    required this.group,
    required this.event,
    required this.canUnpin,
    required this.onUnpin,
  });

  final CommunityGroup group;
  final GroupEvent? event;
  final bool canUnpin;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final eventPinned = group.pinnedEventId != null;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(
          eventPinned ? Icons.event_available : Icons.push_pin_outlined,
        ),
        title: Text(
          eventPinned ? event?.title ?? 'Sabitlenmiş etkinlik' : 'Sabit mesaj',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: eventPinned
            ? Text(event?.dateLabel ?? 'Etkinlik bilgisi yükleniyor')
            : Text(
                group.pinnedMessageText ?? 'Mesaj',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: canUnpin
            ? IconButton(
                tooltip: 'Sabitlemeyi kaldır',
                onPressed: onUnpin,
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }
}

class _ChatEventCard extends StatelessWidget {
  const _ChatEventCard({
    required this.apiService,
    required this.group,
    required this.event,
    required this.onChanged,
    this.onPin,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final GroupEvent event;
  final ValueChanged<GroupEvent> onChanged;
  final VoidCallback? onPin;

  Future<void> _toggle(BuildContext context) async {
    await EcoHaptics.light();
    try {
      final updated = event.isAttending
          ? await apiService.leaveGroupEvent(
              groupId: group.id,
              eventId: event.id,
            )
          : await apiService.updateGroupEventRsvp(
              groupId: group.id,
              eventId: event.id,
              status: 'ATTENDING',
            );
      onChanged(updated);
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
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Katılımcılar (${event.attendeeCount}/${event.capacity})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (event.attendees.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text('Henüz katılan kimse yok.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: event.attendees.length,
                  itemBuilder: (context, index) {
                    final attendee = event.attendees[index];
                    return ListTile(
                      leading: _AttendeeAvatar(attendee: attendee),
                      title: Text(attendee.fullName),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = event.capacity == 0
        ? 0.0
        : (event.attendeeCount / event.capacity).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 14),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        tint: colors.tertiaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.coverImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  event.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.event_available, size: 46),
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
                      Icon(Icons.event_available, color: colors.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (onPin != null)
                        IconButton(
                          tooltip: 'Etkinliği sabitle',
                          onPressed: onPin,
                          icon: const Icon(Icons.push_pin_outlined),
                        ),
                    ],
                  ),
                  Text(event.description, maxLines: 3),
                  const SizedBox(height: 10),
                  _EventLine(icon: Icons.schedule, text: event.dateLabel),
                  _EventLine(
                    icon: Icons.location_on_outlined,
                    text:
                        '${event.exactAddress}, '
                        '${event.district}/${event.city}',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text(
                    '${event.attendeeCount}/${event.capacity} kontenjan dolu',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (event.attendees.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: event.attendees.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 5),
                        itemBuilder: (_, index) => _AttendeeAvatar(
                          attendee: event.attendees[index],
                          radius: 18,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: event.isFull && !event.isAttending
                              ? null
                              : () {
                                  _toggle(context);
                                },
                          icon: Icon(
                            event.isAttending
                                ? Icons.logout_rounded
                                : Icons.check_circle_outline,
                          ),
                          label: Text(event.isAttending ? 'Ayrıl' : 'Katıl'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Katılımcıları gör',
                        onPressed: () => _showAttendees(context),
                        icon: const Icon(Icons.people_outline),
                      ),
                    ],
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

class _AttendeeAvatar extends StatelessWidget {
  const _AttendeeAvatar({required this.attendee, this.radius = 20});

  final GroupEventAttendee attendee;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundImage: attendee.profilePictureUrl == null
        ? null
        : NetworkImage(attendee.profilePictureUrl!),
    child: attendee.profilePictureUrl == null
        ? Text(attendee.fullName.isEmpty ? 'E' : attendee.fullName[0])
        : null,
  );
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sohbeti ilk başlatan sen ol',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.onAvatarTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = TimeOfDay.fromDateTime(
      message.timestamp.toLocal(),
    ).format(context);
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 17,
                backgroundImage: message.senderProfilePictureUrl == null
                    ? null
                    : NetworkImage(message.senderProfilePictureUrl!),
                child: message.senderProfilePictureUrl == null
                    ? Text(
                        message.senderName.isEmpty
                            ? 'E'
                            : message.senderName[0],
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 310),
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
                decoration: BoxDecoration(
                  color: mine
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: mine ? const Radius.circular(5) : null,
                    bottomLeft: mine ? null : const Radius.circular(5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine)
                      Text(
                        message.senderName,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    if (message.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5, bottom: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.imageUrl!,
                            width: 240,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 240,
                              height: 90,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (message.hasDocument)
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse(message.fileUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  message.fileName ?? 'Belgeyi aç',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (message.message.isNotEmpty) Text(message.message),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 7),
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 17,
                backgroundImage: message.senderProfilePictureUrl == null
                    ? null
                    : NetworkImage(message.senderProfilePictureUrl!),
                child: message.senderProfilePictureUrl == null
                    ? Text(
                        message.senderName.isEmpty
                            ? 'E'
                            : message.senderName[0],
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
