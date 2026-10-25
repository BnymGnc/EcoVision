import 'package:ecovision/models/carbon_footprint.dart';
import 'package:ecovision/models/gamification_state.dart';
import 'package:ecovision/screens/carbon_footprint_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every numeric answer disables cards; clearing restores them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: CarbonFootprintScreen(apiService: _FakeApiService())),
    );
    for (final question in carbonQuestions) {
      final field = find.byKey(ValueKey('carbon-number-${question.id}'));
      await tester.tap(find.text(question.options.first.label));
      await tester.pump();
      await tester.enterText(field, '1');
      await tester.pump();
      final options = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith('Yanıt ') ?? false),
      );
      expect(options, findsNWidgets(question.options.length));
      for (final element in options.evaluate()) {
        expect((element.widget as Semantics).properties.enabled, isFalse);
        expect((element.widget as Semantics).properties.selected, isFalse);
        expect((element.widget as Semantics).properties.onTap, isNull);
      }
      if (question.id == 1) {
        await tester.tap(find.byTooltip('Özel değeri temizle'));
        await tester.pump();
        for (final element in options.evaluate()) {
          expect((element.widget as Semantics).properties.enabled, isTrue);
        }
        await tester.tap(find.text(question.options.first.label));
        await tester.pump();
        await tester.enterText(field, '1');
        await tester.pump();
      }
      await tester.tap(
        find.text(question.id == 20 ? 'Karbonumu Hesapla' : 'Devam Et'),
      );
      await tester.pump(const Duration(milliseconds: 500));
      if (question.id != 20) await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('yirmi hızlı yanıt eski sonucu korur', (tester) async {
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
    'sayısal yanıt doğrudan soru altında görünür ve aralık seçiminin yerine geçer',
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
          expect(find.byType(ExpansionTile), findsNothing);
          final field = find.byKey(ValueKey('carbon-number-${question.id}'));
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
            expect(find.text('0–10000 arasında bir sayı gir.'), findsOneWidget);
          }
          await tester.enterText(field, question.id == 2 ? '250' : '200');
          await tester.pump();
          final options = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.startsWith('Yanıt ') ?? false),
          );
          expect(options, findsNWidgets(question.options.length));
          for (final element in options.evaluate()) {
            expect((element.widget as Semantics).properties.enabled, isFalse);
            expect((element.widget as Semantics).properties.selected, isFalse);
          }
        }
        await tester.tap(
          find.text(question.id == 20 ? 'Karbonumu Hesapla' : 'Devam Et'),
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (question.id != 20) await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      final expected = CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: {for (final q in carbonQuestions) q.id: 0},
        numericAnswers: const {2: 250, 11: 200},
      );
      expect(api.submittedKg, expected.annualKg);
      expect(
        find.text('${expected.annualTons.toStringAsFixed(2)} Ton'),
        findsOneWidget,
      );
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
