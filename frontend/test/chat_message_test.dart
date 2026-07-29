import 'package:ecovision/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zengin sohbet alanlarını geriye uyumlu biçimde ayrıştırır', () {
    final message = ChatMessage.fromJson({
      'id': 42,
      'groupId': 7,
      'senderId': 3,
      'senderName': 'Ada Yeşil',
      'senderUsername': 'ada',
      'message': 'Merhaba @deniz',
      'messageType': 'POLL',
      'timestamp': '2026-07-29T10:00:00Z',
      'replyToMessageId': 40,
      'replyToSenderId': 2,
      'replyToSenderName': 'Deniz',
      'replyToText': 'Ne düşünüyorsunuz?',
      'reactions': [
        {
          'emoji': '👍',
          'userIds': [2, 3],
        },
      ],
      'poll': {
        'id': 9,
        'question': 'Etkinlik günü?',
        'totalVotes': 2,
        'options': [
          {
            'index': 0,
            'text': 'Cumartesi',
            'voterIds': [2, 3],
          },
          {'index': 1, 'text': 'Pazar', 'voterIds': <int>[]},
        ],
      },
    });

    expect(message.replyToMessageId, 40);
    expect(message.reactions.single.userIds, [2, 3]);
    expect(message.poll?.question, 'Etkinlik günü?');
    expect(message.poll?.options.first.voterIds, [2, 3]);
  });
}
