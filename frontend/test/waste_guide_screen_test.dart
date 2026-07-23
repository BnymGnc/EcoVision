import 'package:ecovision/screens/education_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rehber tam olarak on kategoriyi ve dört içerik bölümünü taşır', () {
    expect(wasteGuideItems, hasLength(10));
    expect(wasteGuideItems.map((item) => item.title).toSet(), hasLength(10));
    for (final item in wasteGuideItems) {
      expect(item.fact, startsWith('🌍 Bunu Biliyor Muydun?:'));
      expect(item.aiTip, startsWith('📸 Yapay Zeka Tarama İpucu:'));
      expect(item.journey, startsWith('🏭 Geri Dönüşüm Serüveni:'));
      expect(item.upcycle, startsWith('💡'));
    }
  });

  testWidgets('kategori dokunulduğunda dört bilgi bölümü açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WasteGuideScreen()));

    expect(find.text('Gelişmiş Atık Rehberi'), findsOneWidget);
    expect(find.text('🌍 Bunu Biliyor Muydun?:'), findsNothing);

    await tester.tap(find.text('Plastik Atıklar (PET, HDPE, PVC, PP)'));
    await tester.pumpAndSettle();

    expect(find.text('🌍 Bunu Biliyor Muydun?:'), findsOneWidget);
    expect(find.text('📸 Yapay Zeka Tarama İpucu:'), findsOneWidget);
    expect(find.text('🏭 Geri Dönüşüm Serüveni:'), findsOneWidget);
    expect(find.text('💡 İleri Dönüşüm (Kendin Yap):'), findsOneWidget);
  });
}
