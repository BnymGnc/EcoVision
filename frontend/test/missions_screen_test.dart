import 'package:ecovision/models/quest_progress.dart';
import 'package:ecovision/screens/missions_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ödül alındığında görev listesi görünür kalır', (tester) async {
    final service = _QuestApiService();
    await tester.pumpWidget(
      MaterialApp(home: MissionsScreen(points: 0, apiService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 Plastik Tara'), findsOneWidget);
    await tester.tap(find.text('Puanı Al'));
    await tester.pumpAndSettle();

    expect(find.text('Görev Tamamlandı!'), findsOneWidget);
    await tester.tap(find.text('Harika'));
    await tester.pumpAndSettle();

    expect(find.text('3 Plastik Tara'), findsOneWidget);
    expect(find.text('Ödül alındı'), findsOneWidget);
  });
}

class _QuestApiService extends ApiService {
  bool claimed = false;

  QuestProgress get quest => QuestProgress(
    questId: 7,
    progressId: 11,
    code: 'plastic-3',
    title: '3 Plastik Tara',
    description: 'Üç plastik atığı doğru şekilde tara.',
    rewardPoints: 50,
    targetAmount: 3,
    schedule: 'DAILY',
    domain: 'RECYCLING',
    currentAmount: 3,
    completed: true,
    claimed: claimed,
    checkInAvailable: false,
  );

  @override
  Future<List<QuestProgress>> fetchQuests() async => [quest];

  @override
  Future<QuestClaimResult> claimQuest(int progressId) async {
    claimed = true;
    return QuestClaimResult(
      quest: quest,
      pointsAwarded: 50,
      totalPoints: 50,
      message: 'Ödül eklendi',
    );
  }
}
