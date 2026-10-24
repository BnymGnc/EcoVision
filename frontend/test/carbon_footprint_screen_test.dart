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

  testWidgets(
    'isteğe bağlı yıllık verileri soru altında doğrular ve hesaba katar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
      for (final question in carbonQuestions) {
        await tester.tap(find.text(question.options.first.label));
        await tester.pump();
        if (question.id == 2 || question.id == 11) {
          final tile = find.text('Daha net hesapla (isteğe bağlı)');
          await tester.scrollUntilVisible(
            tile,
            180,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
          );
          await tester.tap(tile);
          await tester.pumpAndSettle();
          final annual = find.text('Yıllık');
          await tester.scrollUntilVisible(
            annual,
            180,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
          );
          await tester.tap(annual);
          await tester.pumpAndSettle();
          final field = find.byKey(
            ValueKey(question.id == 2 ? 'carbon-fuel' : 'carbon-electricity'),
          );
          await tester.scrollUntilVisible(
            field,
            180,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
          );
          if (question.id == 2) {
            await tester.enterText(field, '-10');
            await tester.tap(find.text('Devam Et'));
            await tester.pumpAndSettle();
            expect(
              find.text('Geçerli, negatif olmayan bir tüketim gir.'),
              findsOneWidget,
            );
          }
          await tester.enterText(field, question.id == 2 ? '480' : '2400');
        }
        await tester.tap(
          find.text(question.id == 20 ? 'Karbonumu Hesapla' : 'Devam Et'),
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (question.id != 20) await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(api.submittedKg, 3152);
      expect(find.text('3.15 Ton'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
