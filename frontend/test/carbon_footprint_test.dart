import 'package:ecovision/models/carbon_footprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('veri seti tam olarak yirmi soruyu ve beklenen seçenekleri içerir', () {
    expect(carbonQuestions, hasLength(20));
    expect(
      carbonQuestions.map((question) => question.id).toSet(),
      hasLength(20),
    );
    expect(
      carbonQuestions.map((question) => question.options.length).toList(),
      [4, 4, 4, 4, 4, 3, 3, 3, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    );
    expect(carbonQuestions[15].options.first.kgOfCo2, -200);
  });

  test('en düşük cevaplar yıllık 1000 kg üretir', () {
    final selections = {for (final question in carbonQuestions) question.id: 0};

    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: selections,
    );

    expect(result.annualKg, 1000);
    expect(result.annualTons, 1);
    expect(result.tier, CarbonFootprintTier.natureGuardian);
  });

  test('son seçenekler yıllık 16730 kg üretir', () {
    final selections = {
      for (final question in carbonQuestions)
        question.id: question.options.length - 1,
    };

    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: selections,
    );

    expect(result.annualKg, 16730);
    expect(result.annualTons, closeTo(16.73, 0.0001));
    expect(result.tier, CarbonFootprintTier.carbonMonster);
  });

  test('tier sınırları kilogram üzerinden kesin uygulanır', () {
    expect(
      CarbonFootprintCalculator.tierForKg(3999),
      CarbonFootprintTier.natureGuardian,
    );
    expect(
      CarbonFootprintCalculator.tierForKg(4000),
      CarbonFootprintTier.openToGrowth,
    );
    expect(
      CarbonFootprintCalculator.tierForKg(7000),
      CarbonFootprintTier.openToGrowth,
    );
    expect(
      CarbonFootprintCalculator.tierForKg(7001),
      CarbonFootprintTier.carbonMonster,
    );
  });

  test('eksik cevaplarla sonuç üretmez', () {
    expect(
      () => CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: const {},
      ),
      throwsStateError,
    );
  });

  test('isteğe bağlı tüketim girilmezse eski hesap aynen korunur', () {
    final selections = {for (final q in carbonQuestions) q.id: 0};
    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: selections,
      consumption: const CarbonConsumptionData(),
    );
    expect(result.annualKg, 1000);
    expect(result.consumptionAdjusted, isFalse);
  });

  test(
    'elektrik verisi cihaz ve klima tahmininin yerine geçer, haneye bölünür',
    () {
      final selections = {for (final q in carbonQuestions) q.id: 0};
      final result = CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: selections,
        consumption: const CarbonConsumptionData(
          monthlyElectricityKwh: 200,
          householdMembers: 2,
        ),
      );
      expect(result.annualKg, (1000 - 100 + 200 * 12 * 0.469 / 2).round());
      expect(result.consumptionAdjusted, isTrue);
    },
  );

  test('yakıt girildiğinde özel araç tahminleri yeniden eklenmez', () {
    final selections = {
      for (final q in carbonQuestions) q.id: 0,
      1: 3,
      2: 3,
      4: 3,
    };
    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: selections,
      consumption: const CarbonConsumptionData(
        monthlyFuelLitres: 40,
        fuelType: 'DIESEL',
      ),
    );
    expect(
      result.annualKg,
      (1000 - 100 + 40 * 12 * (10.180 / 3.785411784)).round(),
    );
  });

  test('elektrikli ısıtma elektrik faturasıyla çift sayılmaz', () {
    final selections = {
      for (final q in carbonQuestions) q.id: 0,
      9: 3,
      10: 2,
      12: 2,
    };
    final result = CarbonFootprintCalculator.calculate(
      questions: carbonQuestions,
      selectedOptionIndexes: selections,
      consumption: const CarbonConsumptionData(monthlyElectricityKwh: 0),
    );
    expect(result.annualKg, 700);
  });

  test('hatalı isteğe bağlı tüketim reddedilir', () {
    expect(
      () => CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: {for (final q in carbonQuestions) q.id: 0},
        consumption: const CarbonConsumptionData(monthlyElectricityKwh: -1),
      ),
      throwsArgumentError,
    );
  });
}
