import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image_lib;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../models/cleanup_event.dart';
import '../models/group_mission.dart';
import '../models/event_member.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
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

  StompClient? _stompClient;
  StompUnsubscribe? _messageUnsubscribe;
  StompUnsubscribe? _typingUnsubscribe;
  Timer? _typingDebounce;
  final Map<int, Timer> _typingExpiry = {};
  final Map<int, String> _typingUsers = {};
  bool _realtimeConnected = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  Object? _error;
  String? _currentAttendance;
  late int _attendeeCount;

  @override
  void initState() {
    super.initState();
    _currentAttendance = widget.event.currentUserAttendance;
    _attendeeCount = widget.event.attendeeCount;
    _loadMessages();
    _loadMissions();
    _connectRealtime();
    _messageController.addListener(_onComposingChanged);
    unawaited(widget.apiService.markCommunityRead());
    _scrollController.addListener(_handleScroll);
  }

  Future<void> _rsvp(String status) async {
    try {
      final updated = await widget.apiService.updateEventRsvp(
        widget.event.id,
        status,
      );
      if (!mounted) return;
      setState(() {
        _currentAttendance = updated.currentUserAttendance;
        _attendeeCount = updated.attendeeCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'ATTENDING'
                ? 'Katılımın etkinlik listesine eklendi.'
                : 'Katılamayacağın kaydedildi.',
          ),
          behavior: SnackBarBehavior.floating,
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

  Future<void> _showAttendees() async {
    try {
      final attendees = await widget.apiService.fetchEventAttendees(
        widget.event.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Katılanlar (${attendees.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (attendees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Henüz katılım bildiren kimse yok.'),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: attendees.length,
                      itemBuilder: (context, index) {
                        final attendee = attendees[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: attendee.profilePictureUrl == null
                                ? null
                                : NetworkImage(attendee.profilePictureUrl!),
                            child: attendee.profilePictureUrl == null
                                ? Text('${attendee.avatarLevel}')
                                : null,
                          ),
                          title: Text(attendee.fullName),
                        );
                      },
                    ),
                  ),
              ],
            ),
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

  void _onComposingChanged() {
    if (!(_stompClient?.connected ?? false)) return;
    _stompClient!.send(
      destination: '/app/events/${widget.event.id}/typing',
      body: jsonEncode({'typing': _messageController.text.trim().isNotEmpty}),
    );
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1300), () {
      if (_stompClient?.connected ?? false) {
        _stompClient!.send(
          destination: '/app/events/${widget.event.id}/typing',
          body: jsonEncode({'typing': false}),
        );
      }
    });
  }

  @override
  void dispose() {
    _messageUnsubscribe?.call();
    _typingUnsubscribe?.call();
    _typingDebounce?.cancel();
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    _stompClient?.deactivate();
    _messageController.removeListener(_onComposingChanged);
    _messageController.dispose();
    _scrollController.dispose();
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
          _messageUnsubscribe?.call();
          _typingUnsubscribe?.call();
          _messageUnsubscribe = client.subscribe(
            destination: '/topic/events/${widget.event.id}',
            callback: _onRealtimeMessage,
          );
          _typingUnsubscribe = client.subscribe(
            destination: '/topic/events/${widget.event.id}/typing',
            callback: _onTypingEvent,
          );
        },
        onDisconnect: (_) => _setRealtimeConnected(false),
        onWebSocketDone: () => _setRealtimeConnected(false),
        onWebSocketError: (_) => _setRealtimeConnected(false),
        onStompError: (_) => _setRealtimeConnected(false),
      ),
    );
    _stompClient = client;
    client.activate();
  }

  void _setRealtimeConnected(bool connected) {
    if (mounted && _realtimeConnected != connected) {
      setState(() => _realtimeConnected = connected);
    }
  }

  void _onRealtimeMessage(StompFrame frame) {
    final body = frame.body;
    if (!mounted || body == null || body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      final incoming = ChatMessage.fromJson(decoded);
      final nearBottom =
          !_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent -
                  _scrollController.offset <
              180;
      setState(() {
        _mergeMessage(incoming);
      });
      if (nearBottom) _scrollToBottom();
    } catch (_) {
      // The initial HTTP history remains authoritative for malformed frames.
    }
  }

  void _onTypingEvent(StompFrame frame) {
    final body = frame.body;
    if (!mounted || body == null || body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      final userId = (decoded['userId'] as num).toInt();
      if (userId == widget.apiService.currentUser?.id) return;
      _typingExpiry[userId]?.cancel();
      if (decoded['typing'] == true) {
        setState(() {
          _typingUsers[userId] = (decoded['fullName'] ?? '').toString();
        });
        _typingExpiry[userId] = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingUsers.remove(userId));
        });
      } else {
        setState(() => _typingUsers.remove(userId));
      }
    } catch (_) {
      // Typing events are ephemeral; malformed frames can be ignored.
    }
  }

  void _mergeMessage(ChatMessage incoming) {
    final index = _messages.indexWhere((item) => item.id == incoming.id);
    if (index == -1) {
      _messages.add(incoming);
    } else {
      _messages[index] = incoming;
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
    await EcoHaptics.light();
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
      setState(() => _mergeMessage(message));
      _scrollToBottom();
      await EcoHaptics.light();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    await EcoHaptics.light();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF dosyası okunamadı.')));
      }
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF dosyası 2 MB’den küçük olmalıdır.'),
          ),
        );
      }
      return;
    }
    setState(() => _isSending = true);
    try {
      final message = await widget.apiService.sendChatAttachment(
        eventId: widget.event.id,
        bytes: bytes,
        fileName: file.name,
        contentType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() => _mergeMessage(message));
      _scrollToBottom();
      await EcoHaptics.light();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showAttachments() async {
    await showEcoGlassSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            const ListTile(
              title: Text(
                'Sohbete Ekle',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              subtitle: Text('Dosyalar en fazla 2 MB olabilir.'),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_outlined)),
              title: const Text('Fotoğraf'),
              subtitle: const Text('Otomatik olarak sıkıştırılır'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.picture_as_pdf_outlined),
              ),
              title: const Text('PDF Belgesi'),
              subtitle: const Text('Dosyalardan bir PDF seç'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendDocument();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createMission() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '500');
    final unitController = TextEditingController(text: 'şişe');
    final created = await showEcoGlassSheet<bool>(
      context: context,
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
            const EcoSheetHandle(),
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
      await showEcoGlassSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const EcoSheetHandle(),
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
    final submitted = await showEcoGlassSheet<bool>(
      context: context,
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
              const EcoSheetHandle(),
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

    await EcoHaptics.light();
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
        _mergeMessage(message);
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

  Future<void> _openPublicProfile(int userId) async {
    if (userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kullanıcı profili açılamıyor.')),
      );
      return;
    }
    await EcoHaptics.light();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(apiService: widget.apiService, userId: userId),
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    if (message.poll == null) return;
    final canDelete =
        widget.event.isAdmin ||
        widget.event.creatorId == widget.apiService.currentUser?.id ||
        message.senderId == widget.apiService.currentUser?.id;
    if (!canDelete) return;

    await EcoHaptics.selection();
    final action = await showEcoGlassSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EcoSheetHandle(),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Anketi Sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;
    try {
      await widget.apiService.deleteGroupPoll(
        groupId: widget.event.id,
        messageId: message.id,
      );
      if (mounted) {
        setState(() => _messages.removeWhere((item) => item.id == message.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    final isCreator = widget.event.creatorId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () async {
            final deleted = await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => GroupInfoScreen(
                  apiService: widget.apiService,
                  event: widget.event,
                ),
              ),
            );
            if (deleted == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
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
              if (isCreator)
                const PopupMenuItem(
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _typingUsers.isNotEmpty
                  ? _TypingIndicator(
                      key: const ValueKey('typing'),
                      names: _typingUsers.values.take(2).join(', '),
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _send,
              onAttachment: _showAttachments,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageArea(int? currentUserId) {
    if (_isLoading) {
      return const EcoChatShimmer();
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
        if (message.messageType == 'SYSTEM_EVENT') {
          return _EventChatCard(
            event: widget.event,
            attendance: _currentAttendance,
            attendeeCount: _attendeeCount,
            onAttending: () => _rsvp('ATTENDING'),
            onNotAttending: () => _rsvp('NOT_ATTENDING'),
            onAttendees: _showAttendees,
          );
        }
        if (message.isSystem) {
          return _SystemActivityMessage(message: message);
        }
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
              onAvatar: () => _openPublicProfile(message.senderId),
              onLongPress: message.poll == null
                  ? null
                  : () => _showMessageActions(message),
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

class _EventChatCard extends StatelessWidget {
  const _EventChatCard({
    required this.event,
    required this.attendance,
    required this.attendeeCount,
    required this.onAttending,
    required this.onNotAttending,
    required this.onAttendees,
  });

  final CleanupEvent event;
  final String? attendance;
  final int attendeeCount;
  final VoidCallback onAttending;
  final VoidCallback onNotAttending;
  final VoidCallback onAttendees;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.coverImageUrl != null)
                  Image.network(
                    event.coverImageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(event.description),
                      const SizedBox(height: 12),
                      _EventMeta(
                        icon: Icons.schedule_rounded,
                        text: event.dateLabel,
                      ),
                      _EventMeta(
                        icon: Icons.location_on_outlined,
                        text: event.exactAddress.isEmpty
                            ? event.location
                            : '${event.location}\n${event.exactAddress}',
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onAttendees,
                        icon: const Icon(Icons.groups_2_outlined),
                        label: Text('$attendeeCount katılımcıyı görüntüle'),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onAttending,
                              icon: Icon(
                                attendance == 'ATTENDING'
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              label: const Text('Katılıyorum'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onNotAttending,
                              icon: Icon(
                                attendance == 'NOT_ATTENDING'
                                    ? Icons.cancel
                                    : Icons.cancel_outlined,
                              ),
                              label: const Text('Katılamıyorum'),
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
        ),
      ),
    );
  }
}

class _EventMeta extends StatelessWidget {
  const _EventMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isMine,
    required this.onAvatar,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onAvatar;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? colors.primaryContainer : colors.surface;
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
            child: GestureDetector(
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.76)
                      .clamp(220.0, 430.0)
                      .toDouble(),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: 6,
                      left: isMine ? null : -6,
                      right: isMine ? -6 : null,
                      child: CustomPaint(
                        size: const Size(9, 13),
                        painter: _EventBubbleTailPainter(
                          color: bubbleColor,
                          shadowColor: colors.shadow,
                          pointsRight: isMine,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isMine ? const Radius.circular(5) : null,
                          bottomLeft: isMine ? null : const Radius.circular(5),
                        ),
                        border: Border.all(
                          color: isMine
                              ? colors.primary.withValues(alpha: 0.16)
                              : colors.outlineVariant.withValues(alpha: 0.5),
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
                          if (!isMine) ...[
                            Text(
                              message.senderName,
                              style: TextStyle(
                                color: _senderColor(colors, message.senderId),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          if (message.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                          if (message.hasDocument)
                            _DocumentAttachment(message: message),
                          if (message.message.isNotEmpty)
                            Text(
                              message.message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.onSurface,
                                    height: 1.4,
                                  ),
                            ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _time(message.timestamp),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 4),
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

  Color _senderColor(ColorScheme colors, int senderId) =>
      switch (senderId % 3) {
        0 => colors.primary,
        1 => colors.secondary,
        _ => colors.tertiary,
      };
}

class _EventBubbleTailPainter extends CustomPainter {
  const _EventBubbleTailPainter({
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
  bool shouldRepaint(covariant _EventBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.pointsRight != pointsRight;
}

class _SystemActivityMessage extends StatelessWidget {
  const _SystemActivityMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
        ),
        child: Text(
          message.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSecondaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DocumentAttachment extends StatelessWidget {
  const _DocumentAttachment({required this.message});
  final ChatMessage message;

  Future<void> _open(BuildContext context) async {
    await EcoHaptics.light();
    final source = Uri.tryParse(message.fileUrl ?? '');
    final uri = source?.replace(
      queryParameters: {...source.queryParameters, 'download': 'true'},
    );
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF dosyası açılamadı.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: colors.error, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'PDF Belgesi',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    _sizeLabel(message.fileSizeBytes),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Belgeyi indir';
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(2)} MB • Belgeyi indir';
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
    required this.onAttachment,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

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
            tooltip: 'Fotoğraf veya PDF ekle',
            onPressed: isSending ? null : onAttachment,
            icon: const Icon(Icons.add_circle_outline_rounded),
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.names, super.key});

  final String names;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 5, 18, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${widget.names} yazıyor...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
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
