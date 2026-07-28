class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderUsername = '',
    this.senderAvatarLevel = 1,
    required this.message,
    required this.timestamp,
    this.senderProfilePictureUrl,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.contentType,
    this.messageType = 'USER',
  });

  final int id;
  final int eventId;
  final int? groupId;
  final int senderId;
  final String senderName;
  final String senderUsername;
  final int senderAvatarLevel;
  final String message;
  final DateTime timestamp;
  final String? senderProfilePictureUrl;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final String? contentType;
  final String messageType;

  bool get isSystem => messageType.startsWith('SYSTEM_');
  bool get hasDocument => fileUrl != null && fileUrl!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num? ?? json['groupId'] as num? ?? 0)
          .toInt(),
      groupId: (json['groupId'] as num?)?.toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderName: (json['senderName'] ?? 'EcoVision Kullanıcısı').toString(),
      senderUsername: (json['senderUsername'] ?? '').toString(),
      senderAvatarLevel: (json['senderAvatarLevel'] as num? ?? 1).toInt(),
      message: (json['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      senderProfilePictureUrl: json['senderProfilePictureUrl']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      contentType: json['contentType']?.toString(),
      messageType: (json['messageType'] ?? 'USER').toString(),
    );
  }
}
