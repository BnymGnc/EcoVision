import 'package:ecovision/models/chat_message.dart';
import 'package:ecovision/models/community_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kurucu rolü tüm grup yönetim haklarını açar', () {
    final group = CommunityGroup.fromJson({
      'id': 7,
      'creatorId': 1,
      'creatorName': 'Ada Eco',
      'name': 'Kampüs Temizliği',
      'description': 'Birlikte temizliyoruz',
      'city': 'Kayseri',
      'district': 'Talas',
      'memberLimit': 20,
      'memberCount': 8,
      'privateGroup': false,
      'currentUserRole': 'FOUNDER',
      'pinnedEventId': 11,
      'createdAt': '2026-07-28T10:00:00Z',
    });

    expect(group.isFounder, isTrue);
    expect(group.isAdmin, isTrue);
    expect(group.pinnedEventId, 11);
  });

  test('etkinlik kontenjanı ve katılımcıları ayrıştırılır', () {
    final event = GroupEvent.fromJson({
      'id': 11,
      'groupId': 7,
      'creatorId': 1,
      'creatorName': 'Ada Eco',
      'title': 'Park Temizliği',
      'description': 'Parkta buluşuyoruz',
      'eventDate': '2026-08-01T11:00:00Z',
      'city': 'Kayseri',
      'district': 'Talas',
      'exactAddress': 'Mevlana Parkı',
      'capacity': 2,
      'attendeeCount': 2,
      'currentUserAttendance': 'ATTENDING',
      'attendees': [
        {'userId': 1, 'fullName': 'Ada Eco'},
        {'userId': 2, 'fullName': 'Deniz Eco'},
      ],
    });

    expect(event.isFull, isTrue);
    expect(event.isAttending, isTrue);
    expect(event.attendees, hasLength(2));
  });

  test('sohbet mesajı grup etkinliği kimliğini taşır', () {
    final message = ChatMessage.fromJson({
      'id': 99,
      'eventId': null,
      'groupId': 7,
      'groupEventId': 11,
      'senderId': 1,
      'senderName': 'Ada Eco',
      'message': 'Yeni etkinlik',
      'messageType': 'SYSTEM_EVENT',
      'timestamp': '2026-07-28T10:00:00Z',
    });

    expect(message.groupEventId, 11);
    expect(message.isSystem, isTrue);
  });
}
