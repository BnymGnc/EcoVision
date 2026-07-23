import 'package:ecovision/models/carbon_footprint.dart';
import 'package:ecovision/models/gamification_state.dart';
import 'package:ecovision/screens/carbon_footprint_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('yirmi soruyu hesaplayıp üç saniye sonra sonucu gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: CarbonFootprintScreen(
          apiService: api,
          calculationDuration: const Duration(milliseconds: 300),
        ),
      ),
    );

    for (var index = 0; index < carbonQuestions.length; index++) {
      final question = carbonQuestions[index];
      expect(find.text(question.question), findsOneWidget);
      await tester.tap(find.text(question.options.first.label));
      await tester.pump();
      await tester.tap(
        find.text(
          index == carbonQuestions.length - 1
              ? 'Karbonumu Hesapla'
              : 'Devam Et',
        ),
      );
      if (index == carbonQuestions.length - 1) {
        await tester.pump();
      } else {
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Karbon motoru çalışıyor'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(api.submittedKg, 1000);
    expect(find.text('1.00 Ton'), findsOneWidget);
    expect(find.text('Doğa Koruyucusu'), findsOneWidget);
    expect(find.text('Karbonunu Sıfırlamaya Başla!'), findsOneWidget);
  });
}

class _FakeApiService extends ApiService {
  int? submittedKg;

  @override
  Future<GamificationState> completeCarbonFootprint(int score) async {
    submittedKg = score;
    return const GamificationState(
      totalPoints: 75,
      carbonFootprintCompleted: true,
      redeemedRewardKeys: {},
      pointsAwarded: 75,
      message: 'Tamamlandı',
      badge: 'Karbon Bilinci',
    );
  }
}
