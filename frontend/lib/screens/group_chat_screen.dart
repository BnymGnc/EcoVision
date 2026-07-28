import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../models/community_group.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
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
  final _message = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = const [];
  Timer? _poller;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final messages = await widget.apiService.fetchGroupMessages(
        widget.group.id,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    await EcoHaptics.light();
    setState(() => _sending = true);
    try {
      final sent = await widget.apiService.sendGroupMessage(
        groupId: widget.group.id,
        message: text,
      );
      _message.clear();
      if (mounted) setState(() => _messages = [..._messages, sent]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ek dosya 2 MB altında olmalıdır.')),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'image/jpeg',
      };
      final sent = await widget.apiService.sendGroupChatAttachment(
        groupId: widget.group.id,
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
      );
      if (mounted) setState(() => _messages = [..._messages, sent]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.apiService.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.group.coverImageUrl == null
                  ? null
                  : NetworkImage(widget.group.coverImageUrl!),
              child: widget.group.coverImageUrl == null
                  ? const Icon(Icons.groups_2_outlined)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.group.name, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.group.memberCount} üye',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const EcoChatShimmer()
                : _messages.isEmpty
                ? const _ChatEmpty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      return _MessageBubble(
                        message: item,
                        mine: item.senderId == currentUserId,
                        onAvatarTap: item.senderId <= 0
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PublicProfileScreen(
                                    apiService: widget.apiService,
                                    userId: item.senderId,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fotoğraf veya PDF ekle',
                    onPressed: _sending ? null : _attach,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  const SizedBox(width: 4),
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
                  const SizedBox(width: 8),
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
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = TimeOfDay.fromDateTime(
      message.timestamp.toLocal(),
    ).format(context);
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
                radius: 16,
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
              decoration: BoxDecoration(
                color: mine
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: mine ? const Radius.circular(4) : null,
                  bottomLeft: mine ? null : const Radius.circular(4),
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
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          message.imageUrl!,
                          width: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 220,
                            height: 80,
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
          if (mine) const SizedBox(width: 36),
        ],
      ),
    );
  }
}
