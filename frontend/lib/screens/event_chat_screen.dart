import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/cleanup_event.dart';
import '../services/api_service.dart';

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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  Timer? _timer;
  bool _isLoading = true;
  bool _isSending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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
      final messages = await widget.apiService.fetchMessages(widget.event.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.apiService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.event.location,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_error != null) {
                    return Center(
                      child: FilledButton(
                        onPressed: _loadMessages,
                        child: const Text('Retry chat'),
                      ),
                    );
                  }
                  if (_messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the cleanup chat.'),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message.senderId == currentUserId;
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(message.message),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message volunteers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
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
