import '../core/media_url.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    this.groupId,
    this.groupEventId,
    required this.senderId,
    required this.senderName,
    this.senderUsername = '',
    this.senderAvatarLevel = 1,
    this.senderHighestAvatarLevel = 1,
    this.senderProfileImagePreference = 'AVATAR',
    this.senderProfileVisibility = 'FRIENDS_ONLY',
    this.senderSelectedAvatarPath,
    this.senderAdult = false,
    required this.message,
    required this.timestamp,
    this.senderProfilePictureUrl,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.contentType,
    this.messageType = 'USER',
    this.deleted = false,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToSenderName,
    this.replyToText,
    this.reactions = const [],
    this.poll,
  });

  final int id;
  final int eventId;
  final int? groupId;
  final int? groupEventId;
  final int senderId;
  final String senderName;
  final String senderUsername;
  final int senderAvatarLevel;
  final int senderHighestAvatarLevel;
  final String senderProfileImagePreference;
  final String senderProfileVisibility;
  final String? senderSelectedAvatarPath;
  final bool senderAdult;
  final String message;
  final DateTime timestamp;
  final String? senderProfilePictureUrl;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? contentType;
  final String messageType;
  final bool deleted;
  final int? replyToMessageId;
  final int? replyToSenderId;
  final String? replyToSenderName;
  final String? replyToText;
  final List<ChatReaction> reactions;
  final ChatPoll? poll;

  bool get isSystem => messageType.startsWith('SYSTEM_');
  bool get hasDocument => fileUrl != null && fileUrl!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num? ?? json['groupId'] as num? ?? 0)
          .toInt(),
      groupId: (json['groupId'] as num?)?.toInt(),
      groupEventId: (json['groupEventId'] as num?)?.toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderName: (json['senderName'] ?? 'EcoVision Kullanıcısı').toString(),
      senderUsername: (json['senderUsername'] ?? '').toString(),
      senderAvatarLevel: (json['senderAvatarLevel'] as num? ?? 1).toInt(),
      senderHighestAvatarLevel:
          (json['senderHighestAvatarLevel'] as num? ??
                  json['senderAvatarLevel'] as num? ??
                  1)
              .toInt(),
      senderProfileImagePreference:
          (json['senderProfileImagePreference'] ??
                  (json['senderProfilePictureUrl'] == null
                      ? 'AVATAR'
                      : 'CUSTOM_PHOTO'))
              .toString(),
      senderProfileVisibility:
          (json['senderProfileVisibility'] ?? 'FRIENDS_ONLY').toString(),
      senderSelectedAvatarPath: json['senderSelectedAvatarPath']?.toString(),
      senderAdult: json['senderAdult'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      senderProfilePictureUrl: MediaUrl.resolve(
        json['senderProfilePictureUrl'],
      ),
      imageUrl: MediaUrl.resolve(json['imageUrl']),
      fileUrl: MediaUrl.resolve(json['fileUrl']),
      fileName: json['fileName']?.toString(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      contentType: json['contentType']?.toString(),
      messageType: (json['messageType'] ?? 'USER').toString(),
      deleted: json['deleted'] as bool? ?? false,
      replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
      replyToSenderId: (json['replyToSenderId'] as num?)?.toInt(),
      replyToSenderName: json['replyToSenderName']?.toString(),
      replyToText: json['replyToText']?.toString(),
      reactions: (json['reactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChatReaction.fromJson)
          .toList(),
      poll: json['poll'] is Map<String, dynamic>
          ? ChatPoll.fromJson(json['poll'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ChatReaction {
  const ChatReaction({required this.emoji, required this.userIds});

  final String emoji;
  final List<int> userIds;

  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
    emoji: (json['emoji'] ?? '').toString(),
    userIds: (json['userIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(),
  );
}

class ChatPoll {
  const ChatPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.totalVotes,
  });

  final int id;
  final String question;
  final List<ChatPollOption> options;
  final int totalVotes;

  factory ChatPoll.fromJson(Map<String, dynamic> json) => ChatPoll(
    id: (json['id'] as num? ?? 0).toInt(),
    question: (json['question'] ?? '').toString(),
    options: (json['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatPollOption.fromJson)
        .toList(),
    totalVotes: (json['totalVotes'] as num? ?? 0).toInt(),
  );
}

class ChatPollOption {
  const ChatPollOption({
    required this.index,
    required this.text,
    required this.voterIds,
  });

  final int index;
  final String text;
  final List<int> voterIds;

  factory ChatPollOption.fromJson(Map<String, dynamic> json) => ChatPollOption(
    index: (json['index'] as num? ?? 0).toInt(),
    text: (json['text'] ?? '').toString(),
    voterIds: (json['voterIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(),
  );
}
