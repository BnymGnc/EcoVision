import 'package:ecovision/widgets/recycling_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scenario is separate from annual emissions, explains assumptions on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecyclingSummaryCard(
                summary: const {
                  'recyclableScanCount': 10,
                  'modeledScanCount': 7,
                  'potentialKgCo2e': 0.1234,
                  'materials': [
                    {
                      'material': 'pet',
                      'scanCount': 7,
                      'potentialKgCo2e': 0.1234,
                    },
                  ],
                  'factorVersion': 'scenario-test',
                },
                loading: false,
                failed: false,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 ayrıştırma taraması'), findsOneWidget);
      expect(find.text('0,123 kg CO₂e potansiyeli'), findsOneWidget);
      expect(find.textContaining('3 taramanın'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Hesaplama varsayımları'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PET 25 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing or failed server does not become fabricated zero', (
    tester,
  ) async {
    var retry = false;
    for (final failed in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecyclingSummaryCard(
              summary: null,
              loading: false,
              failed: failed,
              onRetry: () => retry = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0,000 kg CO₂e potansiyeli'), findsNothing);
      if (failed) {
        await tester.tap(find.textContaining('Tekrar dene'));
        expect(retry, isTrue);
      } else {
        expect(find.textContaining('sunucu güncellemesi'), findsOneWidget);
      }
    }
  });
}
