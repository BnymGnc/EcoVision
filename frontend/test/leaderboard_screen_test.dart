import 'package:ecovision/models/leaderboard_entry.dart';
import 'package:ecovision/screens/leaderboard_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'global default, city filter, pagination and friends remain independent',
    (tester) async {
      final api = _LeaderboardApi();
      await tester.pumpWidget(
        MaterialApp(home: LeaderboardScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(api.requests, [(null, 0)]);
      expect(find.text('Genel'), findsOneWidget);
      expect(find.text('Tüm şehirler'), findsOneWidget);
      expect(find.text('Global User'), findsOneWidget);
      await tester.ensureVisible(find.text('Diğer kullanıcılar'));
      await tester.tap(find.text('Diğer kullanıcılar'));
      await tester.pumpAndSettle();
      expect(api.requests.last, (null, 1));
      expect(find.text('Second User'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adana').last);
      await tester.pumpAndSettle();
      expect(api.requests.last, ('Adana', 0));
      expect(find.text('City User'), findsOneWidget);
      expect(find.text('Global User'), findsNothing);
      await tester.tap(find.text('Arkadaşlarım').first);
      await tester.pumpAndSettle();
      expect(find.text('Friend User'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _LeaderboardApi extends ApiService {
  final requests = <(String?, int)>[];
  LeaderboardEntry entry(String name, int rank) => LeaderboardEntry(
    rank: rank,
    userId: rank,
    fullName: name,
    city: 'Adana',
    totalPoints: 100 - rank,
    currentUser: false,
  );
  @override
  Future<LeaderboardPage> fetchLeaderboard({String? city, int page = 0}) async {
    requests.add((city, page));
    return LeaderboardPage(
      items: [
        entry(
          city != null
              ? 'City User'
              : page == 0
              ? 'Global User'
              : 'Second User',
          page + 1,
        ),
      ],
      hasMore: city == null && page == 0,
    );
  }

  @override
  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard() async => [
    entry('Friend User', 1),
  ];
}
