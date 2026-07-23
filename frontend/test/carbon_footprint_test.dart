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
}
