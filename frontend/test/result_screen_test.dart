import 'package:ecovision/models/scan_result.dart';
import 'package:ecovision/screens/result_screen.dart';
import 'package:ecovision/screens/education_detail_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI kapsamı görünür ve eşleşen kaynaklı rehber açılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          apiService: _GuideApi(),
          result: ScanResult(
            material: 'Cam Atık',
            isRecyclable: true,
            decayYears: 'Değişir',
            recycledInto: 'Yeni ambalaj',
            scannedAt: DateTime(2026, 10, 24),
            provider: 'ONNX_CPU',
            modelVersion: 'test-local-model',
            detections: const [
              WasteDetection(
                type: 'CAM',
                material: 'Cam',
                confidence: 0.8,
                machineEligible: true,
                eligibilityLabel: 'Belirsiz',
              ),
            ],
          ),
          onFindBins: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yapay zeka analizi'));
    await tester.pumpAndSettle();
    expect(find.text('Model: test-local-model'), findsOneWidget);
    final guide = find.text('Bu Atığın Ayırma Rehberi');
    await tester.scrollUntilVisible(
      guide,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(guide);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(EducationDetailScreen), findsOneWidget);
    expect(find.text('Cam Atıklar: Şişe ile Seramiği Ayır'), findsOneWidget);
    expect(find.text('Bu Modül Tamamlandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'PLASTIK': null,
    'PET': 'pet',
    'CAM': 'glass',
    'ALUMINUM': 'aluminum',
  }.entries) {
    testWidgets(
      '${entry.key}: tarama sonucundan doğrudan DOA haritası açılır',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? filter;
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ResultScreen(
                        apiService: ApiService(),
                        result: ScanResult(
                          material: entry.key,
                          isRecyclable: true,
                          decayYears: '450 yıl',
                          recycledInto: 'Yeni ambalaj',
                          scannedAt: DateTime(2026, 10, 24),
                          detections: [
                            WasteDetection(
                              type: entry.key,
                              material: entry.key,
                              confidence: 0.9,
                              machineEligible: false,
                              eligibilityLabel: 'Belirsiz',
                            ),
                          ],
                        ),
                        onFindBins: (material) {
                          opened = true;
                          filter = material;
                        },
                      ),
                    ),
                  ),
                  child: const Text('Sonucu aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Sonucu aç'));
        await tester.pumpAndSettle();
        expect(find.text('Ambalajı kontrol et'), findsNothing);
        expect(find.text('Gerçekleştirdiğim Eylemi Kaydet'), findsNothing);
        final button = find.text('DOA Makinelerini Haritada Göster');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        expect(filter, entry.value);
        expect(find.text('Sonucu aç'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _GuideApi extends ApiService {
  @override
  Future<Set<String>> fetchEducationProgress() async => {'modul-2'};
}
