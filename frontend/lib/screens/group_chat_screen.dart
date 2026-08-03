import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../models/community_group.dart';
import '../models/event_member.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import 'group_details_screen.dart';
import 'public_profile_screen.dart';

enum _ChatAttachmentAction { camera, gallery, document }

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
  StompClient? _stompClient;
  StompUnsubscribe? _unsubscribe;
  StompUnsubscribe? _typingUnsubscribe;
  Timer? _typingDebounce;
  final Map<int, Timer> _typingExpiry = {};
  final Map<int, String> _typingUsers = {};
  List<EventMember> _members = const [];
  ChatMessage? _replyingTo;
  bool _realtimeConnected = false;
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
    _message.addListener(_onComposerChanged);
    _loadInitial();
    _connectRealtime();
    _poller = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _unsubscribe?.call();
    _typingUnsubscribe?.call();
    _typingDebounce?.cancel();
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    _stompClient?.deactivate();
    _message.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _connectRealtime() {
    final authorization = widget.apiService.authorizationHeader;
    if (authorization == null) return;
    late final StompClient client;
    client = StompClient(
      config: StompConfig(
        url: widget.apiService.webSocketUrl,
        stompConnectHeaders: {'Authorization': authorization},
        webSocketConnectHeaders: {'Authorization': authorization},
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 12),
        onConnect: (_) {
          if (!mounted) return;
          setState(() => _realtimeConnected = true);
          _unsubscribe?.call();
          _unsubscribe = client.subscribe(
            destination: '/topic/groups/${_group.id}',
            callback: _onRealtimeMessage,
          );
          _typingUnsubscribe = client.subscribe(
            destination: '/topic/groups/${_group.id}/typing',
            callback: _onTypingEvent,
          );
        },
        onDisconnect: (_) {
          if (mounted) setState(() => _realtimeConnected = false);
        },
        onWebSocketDone: () {
          if (mounted) setState(() => _realtimeConnected = false);
        },
        onWebSocketError: (_) {
          if (mounted) setState(() => _realtimeConnected = false);
        },
        onStompError: (_) {
          if (mounted) setState(() => _realtimeConnected = false);
        },
      ),
    );
    _stompClient = client;
    client.activate();
  }

  void _onTypingEvent(StompFrame frame) {
    final body = frame.body;
    if (!mounted || body == null) return;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final userId = (json['userId'] as num).toInt();
      if (userId == widget.apiService.currentUser?.id) return;
      _typingExpiry[userId]?.cancel();
      if (json['typing'] == true) {
        setState(() {
          _typingUsers[userId] = (json['fullName'] ?? '').toString();
        });
        _typingExpiry[userId] = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingUsers.remove(userId));
        });
      } else {
        setState(() => _typingUsers.remove(userId));
      }
    } catch (_) {
      // A malformed typing frame is short-lived and can be ignored.
    }
  }

  void _onComposerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!(_stompClient?.connected ?? false)) return;
    _stompClient!.send(
      destination: '/app/groups/${_group.id}/typing',
      body: jsonEncode({'typing': _message.text.trim().isNotEmpty}),
    );
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1300), () {
      if (_stompClient?.connected ?? false) {
        _stompClient!.send(
          destination: '/app/groups/${_group.id}/typing',
          body: jsonEncode({'typing': false}),
        );
      }
    });
  }

  void _onRealtimeMessage(StompFrame frame) {
    final body = frame.body;
    if (!mounted || body == null || body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      final incoming = ChatMessage.fromJson(decoded);
      final nearBottom =
          !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.offset < 180;
      setState(() {
        if (incoming.deleted && incoming.messageType == 'POLL') {
          _messages = _messages
              .where((message) => message.id != incoming.id)
              .toList();
        } else {
          _messages = _mergeMessages(_messages, [incoming]);
        }
      });
      if (incoming.messageType == 'SYSTEM_EVENT') {
        unawaited(_poll(forceMetadata: true));
      }
      if (nearBottom) _scrollToBottom();
    } on FormatException {
      // The HTTP fallback reconciles state if a malformed frame is received.
    }
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
        widget.apiService.fetchCommunityGroupMembers(_group.id),
      ]);
      if (!mounted) return;
      final messages = result[1] as List<ChatMessage>;
      setState(() {
        _group = result[0] as CommunityGroup;
        _messages = messages;
        _historyOffset = messages.length;
        _members = result[2] as List<EventMember>;
        _hasMore = messages.length == _pageSize;
        _loading = false;
      });
      unawaited(_refreshEvents());
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  Future<void> _refreshEvents() async {
    try {
      final loaded = await widget.apiService.fetchGroupEvents(_group.id);
      if (!mounted) return;
      setState(() => _events = {for (final event in loaded) event.id: event});
    } catch (error) {
      if (mounted && _events.isEmpty) _showError(error);
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
    final result =
        byId.values
            .where(
              (message) => !(message.deleted && message.messageType == 'POLL'),
            )
            .toList()
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
        replyToMessageId: _replyingTo?.id,
      );
      if (!mounted) return;
      _message.clear();
      setState(() {
        _replyingTo = null;
        _messages = _mergeMessages(_messages, [sent]);
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    await EcoHaptics.light();
    final action = await showEcoGlassSheet<_ChatAttachmentAction>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamerayla Fotoğraf Çek'),
              onTap: () => Navigator.pop(context, _ChatAttachmentAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Fotoğraf Seç'),
              onTap: () =>
                  Navigator.pop(context, _ChatAttachmentAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF Belgesi Seç'),
              onTap: () =>
                  Navigator.pop(context, _ChatAttachmentAction.document),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ChatAttachmentAction.camera:
        await _pickAndSendImage(ImageSource.camera);
        break;
      case _ChatAttachmentAction.gallery:
        await _pickAndSendImage(ImageSource.gallery);
        break;
      case _ChatAttachmentAction.document:
        await _pickAndSendDocument();
        break;
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
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
      if (bytes.length > 2 * 1024 * 1024) {
        throw const ApiException(
          'Fotoğraf sıkıştırıldıktan sonra da 2 MB sınırını aşıyor.',
        );
      }
      final sent = await widget.apiService.sendGroupChatAttachment(
        groupId: _group.id,
        bytes: bytes,
        fileName: 'ecovision_group_chat.jpg',
        contentType: 'image/jpeg',
        replyToMessageId: _replyingTo?.id,
      );
      _acceptSentAttachment(sent);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = selection?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > 2 * 1024 * 1024) {
      _showError('PDF dosyası 2 MB altında olmalıdır.');
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await widget.apiService.sendGroupChatAttachment(
        groupId: _group.id,
        bytes: bytes,
        fileName: file.name,
        contentType: 'application/pdf',
        replyToMessageId: _replyingTo?.id,
      );
      _acceptSentAttachment(sent);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _acceptSentAttachment(ChatMessage sent) {
    if (!mounted) return;
    setState(() {
      _replyingTo = null;
      _messages = _mergeMessages(_messages, [sent]);
    });
    _scrollToBottom();
  }

  Future<void> _openGroupInfo() async {
    final result = await showEcoGlassSheet<String>(
      context: context,
      builder: (_) => _GroupInfoSheet(
        apiService: widget.apiService,
        group: _group,
        members: _members,
      ),
    );
    if (!mounted) return;
    if (result == 'left' || result == 'deleted') {
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

  Future<void> _showMessageActions(ChatMessage message) async {
    await EcoHaptics.selection();
    final action = await showEcoGlassSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '👏', '😂']
                  .map(
                    (emoji) => IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context, 'react:$emoji'),
                      icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  )
                  .toList(),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Yanıtla'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (_group.isAdmin)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Mesajı sabitle'),
                onTap: () => Navigator.pop(context, 'pin'),
              ),
            if (_group.isAdmin ||
                message.senderId == widget.apiService.currentUser?.id)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  message.poll == null ? 'Mesajı sil' : 'Anketi sil',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(
                  context,
                  message.poll == null ? 'delete' : 'delete_poll',
                ),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action.startsWith('react:')) {
        final updated = await widget.apiService.reactToGroupMessage(
          groupId: _group.id,
          messageId: message.id,
          emoji: action.substring(6),
        );
        _replaceMessage(updated);
      } else if (action == 'reply') {
        setState(() => _replyingTo = message);
      } else if (action == 'pin') {
        await _pinMessage(message);
      } else if (action == 'delete') {
        final updated = await widget.apiService.deleteGroupMessage(
          groupId: _group.id,
          messageId: message.id,
        );
        _replaceMessage(updated);
      } else if (action == 'delete_poll') {
        await widget.apiService.deleteGroupPoll(
          groupId: _group.id,
          messageId: message.id,
        );
        if (mounted) {
          setState(
            () => _messages = _messages
                .where((item) => item.id != message.id)
                .toList(),
          );
        }
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _replaceMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() => _messages = _mergeMessages(_messages, [message]));
  }

  Future<void> _createPoll() async {
    final draft = await showEcoGlassSheet<_PollDraft>(
      context: context,
      builder: (_) => const _CreatePollSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      final poll = await widget.apiService.createGroupPoll(
        groupId: _group.id,
        question: draft.question,
        options: draft.options,
      );
      _replaceMessage(poll);
      _scrollToBottom();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _vote(ChatMessage message, int optionIndex) async {
    try {
      final updated = await widget.apiService.voteInGroupPoll(
        groupId: _group.id,
        messageId: message.id,
        optionIndex: optionIndex,
      );
      _replaceMessage(updated);
    } catch (error) {
      _showError(error);
    }
  }

  String? get _mentionQuery {
    final match = RegExp(
      r'(?:^|\s)@([a-zA-Z0-9._çğıöşüÇĞİÖŞÜ]*)$',
    ).firstMatch(_message.text);
    return match?.group(1)?.toLowerCase();
  }

  List<EventMember> get _mentionMatches {
    final query = _mentionQuery;
    if (query == null) return const [];
    return _members
        .where(
          (member) =>
              member.username.toLowerCase().contains(query) ||
              member.fullName.toLowerCase().contains(query),
        )
        .take(5)
        .toList();
  }

  void _insertMention(EventMember member) {
    final text = _message.text;
    final match = RegExp(
      r'(?:^|\s)@[a-zA-Z0-9._çğıöşüÇĞİÖŞÜ]*$',
    ).firstMatch(text);
    if (match == null) return;
    final prefix = text.substring(0, match.start);
    final leadingSpace = match.group(0)!.startsWith(' ') ? ' ' : '';
    _message.value = TextEditingValue(
      text: '$prefix$leadingSpace@${member.username} ',
      selection: TextSelection.collapsed(
        offset:
            prefix.length + leadingSpace.length + member.username.length + 2,
      ),
    );
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
              tooltip: 'Anket oluştur',
              onPressed: _createPoll,
              icon: const Icon(Icons.poll_outlined),
            ),
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
                      if (item.poll != null) {
                        return _PollBubble(
                          message: item,
                          currentUserId: currentUserId,
                          onVote: (index) => _vote(item, index),
                          onLongPress: () => _showMessageActions(item),
                        );
                      }
                      return _SwipeReply(
                        message: item,
                        onReply: () => setState(() => _replyingTo = item),
                        child: _MessageBubble(
                          message: item,
                          mine: item.senderId == currentUserId,
                          currentUsername:
                              widget.apiService.currentUser?.username ?? '',
                          onAvatarTap: item.senderId <= 0
                              ? null
                              : () => _openProfile(item.senderId),
                          onLongPress: item.isSystem
                              ? null
                              : () => _showMessageActions(item),
                        ),
                      );
                    },
                  ),
          ),
          if (_mentionMatches.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 210),
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: _mentionMatches
                    .map(
                      (member) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundImage: member.profilePictureUrl == null
                              ? null
                              : NetworkImage(member.profilePictureUrl!),
                          child: member.profilePictureUrl == null
                              ? Text(member.fullName.characters.first)
                              : null,
                        ),
                        title: Text(member.fullName),
                        subtitle: Text('@${member.username}'),
                        onTap: () => _insertMention(member),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 3, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_typingUsers.values.take(2).join(', ')} yazıyor...',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo!.senderName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _replyingTo!.message.isEmpty
                              ? 'Medya'
                              : _replyingTo!.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yanıtı kapat',
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
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
                  errorBuilder: (context, _, _) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.event_available, size: 46),
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
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sohbeti ilk başlatan sen ol',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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
    required this.currentUsername,
    this.onAvatarTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String currentUsername;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = mine ? colors.primaryContainer : colors.surface;
    final time = TimeOfDay.fromDateTime(
      message.timestamp.toLocal(),
    ).format(context);
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.secondary.withValues(alpha: 0.12)),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: 5,
                        left: mine ? null : -6,
                        right: mine ? -6 : null,
                        child: CustomPaint(
                          size: const Size(9, 13),
                          painter: _BubbleTailPainter(
                            color: bubbleColor,
                            shadowColor: colors.shadow,
                            pointsRight: mine,
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: (MediaQuery.sizeOf(context).width * 0.76)
                              .clamp(220.0, 360.0)
                              .toDouble(),
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(18).copyWith(
                            bottomRight: mine ? const Radius.circular(4) : null,
                            bottomLeft: mine ? null : const Radius.circular(4),
                          ),
                          border: Border.all(
                            color: mine
                                ? colors.primary.withValues(alpha: 0.12)
                                : colors.outlineVariant.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  message.senderName,
                                  style: TextStyle(
                                    color: _senderNameColor(
                                      context,
                                      message.senderId,
                                    ),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            if (message.replyToMessageId != null)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(
                                  top: 5,
                                  bottom: 7,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border(
                                    left: BorderSide(
                                      color: colors.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replyToSenderName ?? 'Yanıt',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      (message.replyToText ?? '').isEmpty
                                          ? 'Medya'
                                          : message.replyToText!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            if (message.imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 5,
                                  bottom: 6,
                                ),
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
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (message.hasDocument)
                              _DocumentMessageCard(message: message),
                            if (message.deleted)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block_outlined, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Bu mesaj silindi',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            else if (message.message.isNotEmpty)
                              _MentionText(
                                text: message.message,
                                currentUsername: currentUsername,
                              ),
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 10.5,
                                        ),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (message.reactions.isNotEmpty)
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: mine ? 0 : 42,
                right: mine ? 8 : 0,
                top: 2,
              ),
              child: Wrap(
                spacing: 5,
                children: message.reactions
                    .map(
                      (reaction) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${reaction.emoji} ${reaction.userIds.length}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Color _senderNameColor(BuildContext context, int senderId) {
    final colors = Theme.of(context).colorScheme;
    return switch (senderId % 3) {
      0 => colors.primary,
      1 => colors.secondary,
      _ => colors.tertiary,
    };
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({
    required this.color,
    required this.shadowColor,
    required this.pointsRight,
  });

  final Color color;
  final Color shadowColor;
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height * 0.72)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height * 0.72)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawShadow(path, shadowColor.withValues(alpha: 0.12), 2, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.pointsRight != pointsRight;
}

class _DocumentMessageCard extends StatelessWidget {
  const _DocumentMessageCard({required this.message});

  final ChatMessage message;

  Future<void> _download(BuildContext context) async {
    await EcoHaptics.light();
    final source = Uri.tryParse(message.fileUrl ?? '');
    if (source == null) return;
    final uri = source.replace(
      queryParameters: {...source.queryParameters, 'download': 'true'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belge indirilemedi. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pdf =
        (message.contentType ?? '').contains('pdf') ||
        (message.fileName ?? '').toLowerCase().endsWith('.pdf');
    return Container(
      width: 270,
      margin: const EdgeInsets.only(top: 6, bottom: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 48,
                decoration: BoxDecoration(
                  color: pdf
                      ? colors.errorContainer
                      : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_rounded,
                  color: pdf ? colors.error : colors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? (pdf ? 'PDF Belgesi' : 'Belge'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${pdf ? 'PDF' : 'DOSYA'} • ${_formatBytes(message.fileSizeBytes)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _download(context),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Belgeyi İndir'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Boyut bilinmiyor';
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}

class _SwipeReply extends StatelessWidget {
  const _SwipeReply({
    required this.message,
    required this.onReply,
    required this.child,
  });

  final ChatMessage message;
  final VoidCallback onReply;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem || message.deleted) return child;
    return Dismissible(
      key: ValueKey('reply-${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await EcoHaptics.selection();
        onReply();
        return false;
      },
      background: const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 18),
          child: Icon(Icons.reply_rounded),
        ),
      ),
      child: child,
    );
  }
}

class _MentionText extends StatelessWidget {
  const _MentionText({required this.text, required this.currentUsername});

  final String text;
  final String currentUsername;

  @override
  Widget build(BuildContext context) {
    final mention = RegExp(r'@[a-zA-Z0-9._çğıöşüÇĞİÖŞÜ]+');
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in mention.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final value = match.group(0)!;
      final mine =
          value.substring(1).toLowerCase() == currentUsername.toLowerCase();
      spans.add(
        TextSpan(
          text: value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: mine ? FontWeight.w900 : FontWeight.w700,
            backgroundColor: mine
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.7)
                : null,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(children: spans));
  }
}

class _PollBubble extends StatelessWidget {
  const _PollBubble({
    required this.message,
    required this.currentUserId,
    required this.onVote,
    required this.onLongPress,
  });

  final ChatMessage message;
  final int? currentUserId;
  final ValueChanged<int> onVote;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final poll = message.poll!;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          width: 340,
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_outlined, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      poll.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...poll.options.map((option) {
                final selected =
                    currentUserId != null &&
                    option.voterIds.contains(currentUserId);
                final ratio = poll.totalVotes == 0
                    ? 0.0
                    : option.voterIds.length / poll.totalVotes;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    onTap: () => onVote(option.index),
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 19,
                                color: selected ? colors.primary : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(option.text)),
                              Text('${(ratio * 100).round()}%'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Text(
                '${poll.totalVotes} oy',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollDraft {
  const _PollDraft(this.question, this.options);

  final String question;
  final List<String> options;
}

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final question = _question.text.trim();
    final options = _options
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return;
    Navigator.pop(context, _PollDraft(question, options));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EcoSheetHandle(),
          Text(
            'Anket Oluştur',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _question,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Soru',
              prefixIcon: Icon(Icons.poll_outlined),
            ),
          ),
          ...List.generate(
            _options.length,
            (index) => Padding(
              padding: const EdgeInsets.only(top: 9),
              child: TextField(
                controller: _options[index],
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: '${index + 1}. seçenek',
                  counterText: '',
                ),
              ),
            ),
          ),
          if (_options.length < 4)
            TextButton.icon(
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Seçenek ekle'),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Anketi Yayınla'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GroupInfoSheet extends StatefulWidget {
  const _GroupInfoSheet({
    required this.apiService,
    required this.group,
    required this.members,
  });

  final ApiService apiService;
  final CommunityGroup group;
  final List<EventMember> members;

  @override
  State<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<_GroupInfoSheet> {
  late final Future<List<ChatMessage>> _media;
  late List<EventMember> _members;

  @override
  void initState() {
    super.initState();
    _media = widget.apiService.fetchGroupMedia(widget.group.id);
    _members = List<EventMember>.from(widget.members);
  }

  Future<void> _leave() async {
    try {
      await widget.apiService.leaveCommunityGroup(widget.group.id);
      if (mounted) Navigator.pop(context, 'left');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openMemberProfile(EventMember member) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          apiService: widget.apiService,
          userId: member.userId,
        ),
      ),
    );
  }

  Future<void> _removeMember(EventMember member) async {
    if (!widget.group.isFounder || member.isFounder) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üye gruptan çıkarılsın mı?'),
        content: Text(
          '${member.fullName} grup sohbetine ve etkinliklerine '
          'artık erişemeyecek.',
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
            child: const Text('Gruptan Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiService.removeCommunityGroupMember(
        widget.group.id,
        member.userId,
      );
      if (!mounted) return;
      setState(
        () => _members.removeWhere((item) => item.userId == member.userId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.fullName} gruptan çıkarıldı.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _membersTab() {
    if (_members.isEmpty) {
      return const Center(child: Text('Grup üyesi bulunamadı.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = _members[index];
        return ListTile(
          onTap: () => _openMemberProfile(member),
          leading: CircleAvatar(
            backgroundImage: member.profilePictureUrl == null
                ? null
                : NetworkImage(member.profilePictureUrl!),
            child: member.profilePictureUrl == null
                ? Text(member.fullName.isEmpty ? 'E' : member.fullName[0])
                : null,
          ),
          title: Text(member.fullName),
          subtitle: Text(
            member.isFounder
                ? 'Kurucu'
                : member.isAdmin
                ? 'Yönetici'
                : 'Üye',
          ),
          trailing: widget.group.isFounder && !member.isFounder
              ? IconButton(
                  tooltip: 'Gruptan çıkar',
                  onPressed: () => _removeMember(member),
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          const EcoSheetHandle(),
          _GroupAvatar(group: widget.group),
          const SizedBox(height: 10),
          Text(
            widget.group.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text('${widget.group.memberCount} katılımcı'),
          const SizedBox(height: 8),
          const TabBar(
            tabs: [
              Tab(text: 'Bilgiler'),
              Tab(text: 'Üyeler'),
              Tab(text: 'Medya'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(widget.group.description),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(widget.group.locationLabel),
                    ),
                    if (widget.group.inviteCode != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link_rounded),
                        title: const Text('Davet kodu'),
                        subtitle: Text(widget.group.inviteCode!),
                        trailing: IconButton(
                          tooltip: 'Kopyala',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.group.inviteCode!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Davet kodu kopyalandı.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => GroupDetailsScreen(
                                apiService: widget.apiService,
                                group: widget.group,
                              ),
                            ),
                          );
                          if (result == true && context.mounted) {
                            Navigator.pop(context, 'deleted');
                          }
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Grup Ayrıntıları'),
                      ),
                    ),
                    if (!widget.group.isFounder) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: _leave,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Gruptan Ayrıl'),
                      ),
                    ],
                  ],
                ),
                _membersTab(),
                FutureBuilder<List<ChatMessage>>(
                  future: _media,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const EcoShimmerList(itemCount: 4);
                    }
                    final media = snapshot.data ?? const [];
                    if (media.isEmpty) {
                      return const Center(
                        child: Text('Henüz paylaşılan fotoğraf yok.'),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: media.length,
                      itemBuilder: (_, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          media[index].imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
