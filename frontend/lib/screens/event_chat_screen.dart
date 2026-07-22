import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image_lib;

import '../models/chat_message.dart';
import '../models/cleanup_event.dart';
import '../models/group_mission.dart';
import '../models/event_member.dart';
import '../services/api_service.dart';
import 'group_info_screen.dart';
import 'public_profile_screen.dart';

class EventChatScreen extends StatefulWidget {
  const EventChatScreen({
    required this.apiService,
    required this.event,
    super.key,
  });

  final ApiService apiService;
  final CleanupEvent event;

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  static const _pageSize = 30;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<GroupMission> _missions = [];

  Timer? _timer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMissions();
    unawaited(widget.apiService.markCommunityRead());
    _scrollController.addListener(_handleScroll);
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final messages = await widget.apiService.fetchMessages(
        widget.event.id,
        limit: _pageSize,
      );
      if (!mounted) {
        return;
      }
      final shouldScroll =
          _messages.isEmpty ||
          messages.any(
            (incoming) =>
                !_messages.any((current) => current.id == incoming.id),
          );
      setState(() {
        if (silent) {
          for (final message in messages) {
            if (!_messages.any((current) => current.id == message.id)) {
              _messages.add(message);
            }
          }
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        } else {
          _messages
            ..clear()
            ..addAll(messages);
          _hasMore = messages.length == _pageSize;
        }
        _isLoading = false;
        _error = null;
      });
      if (shouldScroll || !silent) {
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels < 100 &&
        !_isLoadingOlder &&
        _hasMore) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _isLoadingOlder = true);
    final previousExtent = _scrollController.position.maxScrollExtent;
    try {
      final older = await widget.apiService.fetchMessages(
        widget.event.id,
        limit: _pageSize,
        offset: _messages.length,
      );
      if (!mounted) return;
      final unique = older
          .where((item) => !_messages.any((current) => current.id == item.id))
          .toList();
      setState(() {
        _messages.insertAll(0, unique);
        _hasMore = older.length == _pageSize;
        _isLoadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final addedExtent =
              _scrollController.position.maxScrollExtent - previousExtent;
          _scrollController.jumpTo(addedExtent.clamp(0, double.infinity));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  Future<void> _loadMissions() async {
    try {
      final missions = await widget.apiService.fetchGroupMissions(
        widget.event.id,
      );
      if (mounted) {
        setState(() {
          _missions
            ..clear()
            ..addAll(missions);
        });
      }
    } catch (_) {
      // Chat remains available if mission metadata is temporarily unavailable.
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _isSending = true);
    try {
      var decoded = image_lib.decodeImage(await picked.readAsBytes());
      if (decoded == null) throw const ApiException('Fotoğraf okunamadı.');
      if (decoded.width > 1600 || decoded.height > 1600) {
        decoded = image_lib.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
        );
      }
      var quality = 84;
      var bytes = image_lib.encodeJpg(decoded, quality: quality);
      while (bytes.length > 2 * 1024 * 1024 && quality > 42) {
        quality -= 8;
        bytes = image_lib.encodeJpg(decoded, quality: quality);
      }
      if (bytes.length > 2 * 1024 * 1024)
        throw const ApiException(
          'Fotoğraf sıkıştırıldıktan sonra da 2 MB sınırını aşıyor.',
        );
      final message = await widget.apiService.sendChatImage(
        eventId: widget.event.id,
        bytes: bytes,
        fileName: 'ecovision_chat.jpg',
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showEmojis() {
    const emojis = ['😀', '👏', '🌍', '♻️', '🌱', '💚', '🔥', '⭐', '🙌', '🥳'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: emojis
                .map(
                  (emoji) => InkWell(
                    onTap: () {
                      _messageController.text += emoji;
                      _messageController.selection = TextSelection.collapsed(
                        offset: _messageController.text.length,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _createMission() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '500');
    final unitController = TextEditingController(text: 'şişe');
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grup Görevi Oluştur',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Görev',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hedef'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Birim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final target = int.tryParse(targetController.text.trim());
                  if (titleController.text.trim().isEmpty ||
                      unitController.text.trim().isEmpty ||
                      target == null ||
                      target < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Geçerli bir görev girin.')),
                    );
                    return;
                  }
                  try {
                    await widget.apiService.createGroupMission(
                      eventId: widget.event.id,
                      title: titleController.text,
                      targetAmount: target,
                      unit: unitController.text,
                    );
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Görevi Yayınla'),
              ),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    targetController.dispose();
    unitController.dispose();
    if (created == true) await _loadMissions();
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Temizlik grubu silinsin mi?'),
        content: const Text(
          'Grup görevleri ve konuşmaları kalıcı olarak silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteEvent(widget.event.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showMembers() async {
    try {
      final members = await widget.apiService.fetchEventMembers(
        widget.event.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Grup Üyeleri',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final member in members)
                ListTile(
                  leading: CircleAvatar(child: Text('${member.avatarLevel}')),
                  title: Text(member.fullName),
                  subtitle: Text(member.isAdmin ? 'Yönetici' : 'Üye'),
                  trailing:
                      member.isAdmin ||
                          member.userId == widget.apiService.currentUser?.id
                      ? null
                      : TextButton(
                          onPressed: () => _promoteMember(context, member),
                          child: const Text('Yönetici Yap'),
                        ),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _promoteMember(
    BuildContext sheetContext,
    EventMember member,
  ) async {
    try {
      await widget.apiService.promoteEventAdmin(widget.event.id, member.userId);
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.fullName} artık grup yöneticisi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _createWasteReport() async {
    final countController = TextEditingController();
    String material = 'Plastik';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grup Atık Raporu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: material,
                decoration: const InputDecoration(labelText: 'Atık Türü'),
                items: const ['Plastik', 'Cam', 'Kağıt', 'Metal', 'Elektronik']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setSheetState(() => material = value ?? material),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Toplanan Adet',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final count = int.tryParse(countController.text.trim());
                    if (count == null || count < 1) return;
                    try {
                      await widget.apiService.createGroupWasteReport(
                        eventId: widget.event.id,
                        materialType: material,
                        itemCount: count,
                      );
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.recycling_rounded),
                  label: const Text('Raporu Ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    countController.dispose();
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atık raporu grup toplamına eklendi.')),
      );
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final message = await widget.apiService.sendMessage(
        eventId: widget.event.id,
        message: text,
      );
      if (!mounted) {
        return;
      }
      _messageController.clear();
      setState(() {
        _messages.add(message);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentUserId = widget.apiService.currentUser?.id;
    final isAdmin = widget.event.isAdmin;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupInfoScreen(
                apiService: widget.apiService,
                event: widget.event,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  _initials(widget.event.title),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.event.location} • temizlik grubu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mesajları yenile',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'Grup işlemleri',
            onSelected: (value) {
              if (value == 'report') _createWasteReport();
              if (value == 'members') _showMembers();
              if (value == 'mission') _createMission();
              if (value == 'delete') _deleteGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.recycling_rounded),
                  title: Text('Grup Atık Raporu'),
                ),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'members',
                  child: ListTile(
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('Üyeleri Yönet'),
                  ),
                ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'mission',
                  child: ListTile(
                    leading: Icon(Icons.add_task_rounded),
                    title: Text('Grup Görevi Oluştur'),
                  ),
                ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'Grubu Sil',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_missions.isNotEmpty) _MissionRail(missions: _missions),
            Expanded(
              child: ColoredBox(
                color: colors.surfaceContainerLowest,
                child: _buildMessageArea(currentUserId),
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _send,
              onImage: _pickAndSendImage,
              onEmoji: _showEmojis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageArea(int? currentUserId) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ChatState(
        icon: Icons.cloud_off_outlined,
        title: 'Mesajlar yüklenemedi',
        actionLabel: 'Tekrar Dene',
        onAction: _loadMessages,
      );
    }
    if (_messages.isEmpty) {
      return const _ChatState(
        icon: Icons.forum_outlined,
        title: 'Temizlik sohbetini başlat',
        message: 'Malzeme, ulaşım ve buluşma noktasını burada planlayın.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 20),
      itemCount: _messages.length + (_isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingOlder && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final messageIndex = index - (_isLoadingOlder ? 1 : 0);
        final message = _messages[messageIndex];
        final isMine = message.senderId == currentUserId;
        final showDate =
            messageIndex == 0 ||
            !_sameDay(_messages[messageIndex - 1].timestamp, message.timestamp);
        return Column(
          children: [
            if (showDate) _DateDivider(date: message.timestamp),
            _MessageRow(
              message: message,
              isMine: isMine,
              onAvatar: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(
                    apiService: widget.apiService,
                    userId: message.senderId,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) {
      return 'EV';
    }
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isMine,
    required this.onAvatar,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatar = _EcoChatAvatar(
      level: message.senderAvatarLevel,
      isMine: isMine,
      pictureUrl: message.senderProfilePictureUrl,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            GestureDetector(onTap: onAvatar, child: avatar),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    (isMine ? colors.primary : colors.tertiary).withAlpha(28),
                    colors.surface,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isMine ? 24 : 6),
                    bottomRight: Radius.circular(isMine ? 6 : 24),
                  ),
                  border: isMine
                      ? null
                      : Border.all(color: colors.outlineVariant.withAlpha(150)),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withAlpha(14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine) ...[
                      Text(
                        message.senderName,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    if (message.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.imageUrl!,
                          width: 260,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 220,
                            height: 100,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    if (message.message.isNotEmpty)
                      Text(
                        message.message,
                        style: const TextStyle(height: 1.35),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _time(message.timestamp),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: colors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: onAvatar, child: avatar),
          ],
        ],
      ),
    );
  }

  String _time(DateTime timestamp) {
    final local = timestamp.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _MissionRail extends StatelessWidget {
  const _MissionRail({required this.missions});

  final List<GroupMission> missions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 92,
      color: colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: missions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final mission = missions[index];
          return Container(
            width: 230,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withAlpha(150),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: colors.onSecondaryContainer),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: mission.progress,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${mission.currentAmount}/${mission.targetAmount} ${mission.unit}',
                        style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EcoChatAvatar extends StatelessWidget {
  const _EcoChatAvatar({
    required this.level,
    required this.isMine,
    this.pictureUrl,
  });

  final int level;
  final bool isMine;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isMine
        ? colors.secondaryContainer
        : colors.tertiaryContainer;
    final foreground = isMine
        ? colors.onSecondaryContainer
        : colors.onTertiaryContainer;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: foreground.withAlpha(80), width: 2),
      ),
      child: pictureUrl != null
          ? ClipOval(
              child: Image.network(
                pictureUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.eco_rounded, color: foreground, size: 20),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: foreground,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$level',
                      style: TextStyle(
                        color: background,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final local = date.toLocal();
    final now = DateTime.now();
    final today =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            today
                ? 'Bugün'
                : '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onImage,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onEmoji;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Fotoğraf gönder',
            onPressed: isSending ? null : onImage,
            icon: const Icon(Icons.photo_outlined),
          ),
          IconButton(
            tooltip: 'Emoji seç',
            onPressed: onEmoji,
            icon: const Icon(Icons.emoji_emotions_outlined),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Gönüllülere mesaj yaz',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Mesaj gönder',
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatState extends StatelessWidget {
  const _ChatState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
