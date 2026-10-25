import 'dart:async';
import 'package:ecovision/models/chat_message.dart';
import 'package:ecovision/models/community_group.dart';
import 'package:ecovision/models/event_member.dart';
import 'package:ecovision/models/social_models.dart';
import 'package:ecovision/screens/group_chat_screen.dart';
import 'package:ecovision/screens/main_tab_navigator.dart';
import 'package:ecovision/screens/map_screen.dart';
import 'package:ecovision/screens/profile_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final group = CommunityGroup(
  id: 1,
  creatorId: 1,
  creatorName: 'Test',
  name: 'Grup',
  description: 'Test',
  city: 'Kayseri',
  district: 'Talas',
  memberLimit: 20,
  memberCount: 2,
  privateGroup: false,
  currentUserRole: 'MEMBER',
  createdAt: DateTime(2026, 10, 24),
);

void main() {
  testWidgets('fallback polling tek istek tutar ve arka planda durur', (
    tester,
  ) async {
    final api = _ChatApi();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupChatScreen(apiService: api, group: group),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(api.calls, 2);
    await tester.pump(const Duration(seconds: 24));
    expect(api.calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    api.pending.complete([]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(api.calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.calls, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('ana ekran açılışında kullanılmayan sekmeler yüklenmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MainTabNavigator(apiService: _ChatApi())),
    );
    await tester.pump();
    expect(find.byType(MapScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('mesaj gönderilirken yazılan yeni taslak silinmez', (
    tester,
  ) async {
    final api = _ChatApi()..sentReply = Completer<ChatMessage>();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupChatScreen(apiService: api, group: group),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final composer = find.byType(TextField);
    await tester.enterText(composer, 'İlk mesaj');
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    await tester.enterText(composer, 'Yeni taslak');
    api.sentReply!.complete(
      ChatMessage(
        id: 1,
        eventId: 1,
        groupId: 1,
        senderId: 1,
        senderName: 'Test',
        message: 'İlk mesaj',
        timestamp: DateTime(2026, 10, 24),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<TextField>(composer).controller!.text, 'Yeni taslak');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ChatApi extends ApiService {
  int calls = 0;
  Completer<ChatMessage>? sentReply;
  final pending = Completer<List<ChatMessage>>();
  @override
  Future<CommunityGroup> fetchCommunityGroup(int id) async => group;
  @override
  Future<List<EventMember>> fetchCommunityGroupMembers(int id) async => [];
  @override
  Future<List<SocialUser>> fetchFriends() async => [];
  @override
  Future<List<GroupEvent>> fetchGroupEvents(int id) async => [];
  @override
  Future<List<ChatMessage>> fetchGroupMessages(
    int id, {
    int limit = 30,
    int offset = 0,
  }) async {
    calls++;
    if (calls == 2) return pending.future;
    return [];
  }

  @override
  Future<int> fetchUnreadNotificationCount() async => 0;
  @override
  Future<ChatMessage> sendGroupMessage({
    required int groupId,
    required String message,
    int? replyToMessageId,
  }) => sentReply!.future;
}
