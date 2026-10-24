import 'package:ecovision/screens/detailed_carbon_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('tüketim formu $width genişlikte birimleri korur', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _CarbonApi();
      await tester.pumpWidget(
        MaterialApp(home: DetailedCarbonScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yıllık'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '2400');
      await tester.ensureVisible(find.text('Hesapla ve Kaydet'));
      await tester.tap(find.text('Hesapla ve Kaydet'));
      await tester.pumpAndSettle();
      expect(api.inputs?['monthlyElectricityKwh'], 200.0);
      expect(api.inputs?['monthlyFuelLitres'], isNull);
      expect(find.text('Bilinen tüketimlerin tahmini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CarbonApi extends ApiService {
  Map<String, dynamic>? inputs;
  @override
  Future<List<Map<String, dynamic>>> fetchWasteActions() async => [];
  @override
  Future<Map<String, dynamic>> assessCarbon(Map<String, dynamic> inputs) async {
    this.inputs = inputs;
    return {
      'assessment': {
        'annualKnownKg': 1125.6,
        'monthlyKnownKg': 93.8,
        'annualByCategory': {'electricity': 1125.6},
        'missingCategories': ['Isınma', 'Beslenme'],
        'scope': 'Kısmi tahmin',
        'factors': [],
      },
    };
  }
}
