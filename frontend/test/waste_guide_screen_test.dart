import 'package:ecovision/models/academy_module.dart';
import 'package:ecovision/screens/academy_quiz_screen.dart';
import 'package:ecovision/screens/education_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('akademi JSON modeli üç soruyu doğrular', () {
    final module = AcademyModule.fromJson(_moduleJson);

    expect(module.categoryId, 'modul-1');
    expect(module.questions, hasLength(3));
    expect(module.questions.first.correctOptionIndex, 0);
  });

  testWidgets('iki doğru cevap modülü tamamlanmış olarak işaretler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final module = AcademyModule.fromJson(_moduleJson);
    await tester.pumpWidget(
      MaterialApp(home: WasteGuideScreen(modules: [module])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plastik Akademisi'), findsOneWidget);
    await tester.tap(find.text('Plastik Akademisi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sınavı Başlat'));
    await tester.pumpAndSettle();

    expect(find.byType(AcademyQuizScreen), findsOneWidget);
    for (var question = 0; question < 3; question++) {
      await tester.tap(find.text('Doğru ${question + 1}'));
      await tester.pump();
      await tester.tap(find.text('Cevabı Onayla'));
      await tester.pump();
      await tester.tap(
        find.text(question == 2 ? 'Sonucu Gör' : 'Sonraki Soru'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Modülü Tamamladın!'), findsOneWidget);
    await tester.tap(find.text('Akademiye Dön'));
    await tester.pumpAndSettle();

    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}

final Map<String, dynamic> _moduleJson = {
  'categoryId': 'modul-1',
  'title': 'Plastik Akademisi',
  'contentBody': 'Plastiklerin doğadaki etkisini anlatan akademik içerik.',
  'questions': List.generate(
    3,
    (index) => {
      'questionText': 'Soru ${index + 1}',
      'options': ['Doğru ${index + 1}', 'Yanlış ${index + 1}'],
      'correctOptionIndex': 0,
    },
  ),
};
