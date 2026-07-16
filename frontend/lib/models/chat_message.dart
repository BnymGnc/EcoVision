class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  final int id;
  final int eventId;
  final int senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num).toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderName: (json['senderName'] ?? 'EcoVision User').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
