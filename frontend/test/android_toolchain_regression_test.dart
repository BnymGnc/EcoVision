import 'dart:async';

import 'package:ecovision/models/community_group.dart';
import 'package:ecovision/models/event_member.dart';
import 'package:ecovision/models/social_models.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/screens/avatar_selection_screen.dart';
import 'package:ecovision/screens/group_details_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('avatar selection does not open a dialog after disposal', (
    tester,
  ) async {
    final vibration = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          await vibration.future;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSelectionScreen(
          apiService: ApiService(),
          user: const UserProfile(
            id: 1,
            name: 'Test',
            surname: 'User',
            email: 'test@ecovision.invalid',
            totalPoints: 0,
            role: 'USER',
            city: 'Kayseri',
            ownedMarketItems: {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Seviye 1'));
    await tester.pumpWidget(const SizedBox.shrink());
    vibration.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final failMembers in [false, true]) {
    testWidgets('members sheet reuses the observed prefetch: $failMembers', (
      tester,
    ) async {
      final api = _MembersApi(failMembers: failMembers);
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsScreen(
            apiService: api,
            group: CommunityGroup(
              id: 1,
              creatorId: 1,
              creatorName: 'Test User',
              name: 'Test Grubu',
              description: 'Konum ve uyelik testi',
              city: 'Kayseri',
              district: 'Talas',
              memberLimit: 20,
              memberCount: 1,
              privateGroup: false,
              createdAt: DateTime(2026, 10, 24),
              currentUserRole: 'FOUNDER',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('1 / 20 Üye'));
      await tester.tap(find.text('1 / 20 Üye'));
      await tester.pumpAndSettle();
      expect(api.memberCalls, 1);
      expect(api.friendCalls, 1);
      expect(
        find.text(failMembers ? 'Uyeler yuklenemedi' : 'Test User'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _MembersApi extends ApiService {
  _MembersApi({required this.failMembers});
  final bool failMembers;
  int memberCalls = 0;
  int friendCalls = 0;

  @override
  Future<List<GroupEvent>> fetchGroupEvents(int groupId) async => [];

  @override
  Future<List<SocialUser>> fetchFriends() async {
    friendCalls++;
    return [];
  }

  @override
  Future<List<EventMember>> fetchCommunityGroupMembers(int groupId) async {
    memberCalls++;
    if (failMembers) throw const ApiException('Uyeler yuklenemedi');
    return const [
      EventMember(
        userId: 1,
        username: 'test',
        fullName: 'Test User',
        role: 'FOUNDER',
        avatarLevel: 1,
      ),
    ];
  }
}
