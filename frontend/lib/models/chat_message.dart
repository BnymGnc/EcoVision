class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarLevel = 1,
    required this.message,
    required this.timestamp,
    this.senderProfilePictureUrl,
    this.imageUrl,
  });

  final int id;
  final int eventId;
  final int senderId;
  final String senderName;
  final int senderAvatarLevel;
  final String message;
  final DateTime timestamp;
  final String? senderProfilePictureUrl;
  final String? imageUrl;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num).toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderName: (json['senderName'] ?? 'EcoVision Kullanıcısı').toString(),
      senderAvatarLevel: (json['senderAvatarLevel'] as num? ?? 1).toInt(),
      message: (json['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      senderProfilePictureUrl: json['senderProfilePictureUrl']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}
