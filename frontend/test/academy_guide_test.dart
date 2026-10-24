import 'package:ecovision/models/academy_module.dart';
import 'package:ecovision/screens/education_detail_screen.dart';
import 'package:ecovision/screens/education_guide_screen.dart';
import 'package:ecovision/services/academy_repository.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<AcademyModule> catalog;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    catalog = await const AcademyRepository().loadModules();
  });

  test('10 kaynaklı modül, 30 geçerli soru ve güvenli bağlantılar', () async {
    final modules = catalog;
    expect(modules.length, 10);
    expect(modules.map((m) => m.categoryId).toSet().length, 10);
    for (final module in modules) {
      expect(module.questions, hasLength(3));
      expect(module.preparation.length, greaterThanOrEqualTo(3));
      expect(module.mistakes.length, greaterThanOrEqualTo(3));
      expect(module.acceptedExamples, isNotEmpty);
      expect(module.excludedExamples, isNotEmpty);
      expect(module.aiTip, isNotEmpty);
      expect(module.safetyNote, isNotEmpty);
      expect(module.collectionRoute, isNotEmpty);
      expect(module.sources, isNotEmpty);
      expect(module.readingMinutes, greaterThan(0));
      for (final source in module.sources) {
        expect(source.url.scheme, 'https');
      }
      for (final question in module.questions) {
        expect(
          question.correctOptionIndex,
          inInclusiveRange(0, question.options.length - 1),
        );
      }
    }
  });

  test('Türkçe aramada I, İ ve aksanlar eşleşir', () async {
    final modules = catalog;
    expect(
      modules.firstWhere((m) => m.categoryId == 'modul-7').matches('YAG'),
      isTrue,
    );
    expect(
      modules.firstWhere((m) => m.categoryId == 'modul-3').matches('kağıt'),
      isTrue,
    );
    expect(normalizeGuideText('IŞIK İÇİN'), 'isik icin');
  });

  test('güvensiz kaynak URL reddedilir', () {
    for (final url in [
      'javascript:alert(1)',
      'http://example.org',
      'https://user:pass@example.org',
    ]) {
      expect(
        () => AcademySource.fromJson({'title': 'Kaynak', 'url': url}),
        throwsFormatException,
      );
    }
  });

  testWidgets('arama, tamamlanma filtresi ve boş durum birlikte çalışır', (
    tester,
  ) async {
    final modules = catalog;
    await tester.pumpWidget(
      MaterialApp(
        home: WasteGuideScreen(modules: modules, apiService: _AcademyApi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('academy-search')), 'YAG');
    await tester.pumpAndSettle();
    expect(find.text('Bitkisel Atık Yağ: Lavabodan Uzak Tut'), findsOneWidget);
    await tester.tap(find.text('Tamamlanan'));
    await tester.pumpAndSettle();
    expect(find.text('Bu seçimde modül bulunamadı'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('academy-search')), 'PET');
    await tester.pumpAndSettle();
    expect(
      find.text('Plastik Atıklar: Her Plastik PET Değildir'),
      findsOneWidget,
    );
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final kind in AppThemeKind.values) {
    for (final width in [320.0, 430.0]) {
      testWidgets('ders: ${kind.name}, ${width.toInt()} px ve büyük yazı', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final modules = catalog;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.forKind(kind),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: EducationDetailScreen(
              module: modules.first,
              apiService: null,
              alreadyCompleted: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sınavı Başlat'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Yapay zeka: ipuçları ve sınırlar'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Yapay zeka: ipuçları ve sınırlar'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Kaynaklar'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _AcademyApi extends ApiService {
  @override
  Future<Set<String>> fetchEducationProgress() async => {'modul-1'};
}
