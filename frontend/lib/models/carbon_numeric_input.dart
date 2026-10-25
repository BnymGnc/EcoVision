/// Numeric refinements of the existing survey, not a trained ML predictor.
/// Only electricity and fuel use physical factors; the other curves retain
/// the approximate survey's original annual weights and must be labelled so.
class CarbonNumericInput {
  const CarbonNumericInput(
    this.label,
    this.unit,
    this.maximum,
    this.anchors, {
    this.minimum = 0,
    this.requiresOption = false,
    this.reference,
  });
  final String label;
  final String unit;
  final double minimum;
  final double maximum;
  final bool requiresOption;
  final double? reference;
  final List<(double, double)> anchors;

  String? validate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      return '${minimum.toStringAsFixed(0)}–${maximum.toStringAsFixed(0)} arasında bir sayı gir.';
    }
    return null;
  }

  double annualKg(double value, double optionKg) {
    if (validate('$value') != null) {
      throw ArgumentError('Geçersiz sayısal yanıt');
    }
    if (reference != null) return optionKg * value / reference!;
    // Piecewise interpolation is deterministic and inspectable, not ML.
    var left = anchors[0];
    var right = anchors[1];
    for (var i = 1; i < anchors.length; i++) {
      left = anchors[i - 1];
      right = anchors[i];
      if (value <= right.$1) break;
    }
    final estimate =
        left.$2 +
        (value - left.$1) * (right.$2 - left.$2) / (right.$1 - left.$1);
    return estimate;
  }
}

abstract final class CarbonNumericInputs {
  // Petrol assumption: 7 L/100 km, EPA 8.887 kg CO2/US gallon.
  static const carKgPerKm = 0.07 * 8.887 / 3.785411784;
  static const fields = <int, CarbonNumericInput>{
    1: CarbonNumericInput(
      'Günlük gidiş-dönüş mesafen',
      'km/gün',
      1000,
      [],
      requiresOption: true,
      reference: 20,
    ),
    2: CarbonNumericInput('Haftalık araç / taksi mesafen', 'km/hafta', 10000, [
      (0, 0),
      (1, 52 * carKgPerKm),
    ]),
    3: CarbonNumericInput('Yıllık uçuş sayın', 'uçuş/yıl', 1000, [
      (0, 0),
      (1.5, 500),
      (4, 1500),
      (8, 3000),
    ]),
    4: CarbonNumericInput(
      'Yıllık şehirlerarası mesafen',
      'km/yıl',
      1000000,
      [],
      requiresOption: true,
      reference: 1000,
    ),
    5: CarbonNumericInput('Haftalık et içeren öğünlerin', 'öğün/hafta', 50, [
      (0, 500),
      (2, 1200),
      (7, 2500),
    ]),
    6: CarbonNumericInput('İthal / paketli gıda alışveriş payın', '%', 100, [
      (0, 100),
      (50, 300),
      (100, 700),
    ]),
    7: CarbonNumericInput('Haftalık paket servis sayın', 'sipariş/hafta', 100, [
      (0, 0),
      (0.375, 50),
      (1.5, 200),
      (7, 600),
    ]),
    8: CarbonNumericInput(
      'Haftalık israf edilen yemek',
      'porsiyon/hafta',
      100,
      [(0, 0), (1.5, 150), (7, 400)],
    ),
    9: CarbonNumericInput(
      'Yılda ısınma kullandığın süre',
      'ay/yıl',
      12,
      [],
      requiresOption: true,
      reference: 6,
    ),
    10: CarbonNumericInput('Tahmini ısı kaybı oranı', '%', 100, [
      (0, 0),
      (10, 100),
      (25, 400),
      (50, 800),
    ]),
    11: CarbonNumericInput('Aylık hane elektrik tüketimi', 'kWh/ay', 100000, [
      (0, 0),
      (1, 12 * 0.469),
    ]),
    12: CarbonNumericInput('Yazın günlük klima kullanımı', 'saat/gün', 24, [
      (0, 0),
      (2, 150),
      (8, 500),
    ]),
    13: CarbonNumericInput('Yılda aldığın yeni kıyafet', 'adet/yıl', 1000, [
      (0, 0),
      (2, 50),
      (8, 200),
      (24, 600),
    ]),
    14: CarbonNumericInput(
      'Haftalık tek kullanımlık plastik',
      'adet/hafta',
      1000,
      [(0, 0), (3, 150), (10, 500)],
    ),
    15: CarbonNumericInput('Haftalık kağıt tüketimin', 'sayfa/hafta', 10000, [
      (0, 20),
      (20, 100),
      (70, 300),
    ]),
    16: CarbonNumericInput('Ayırdığın atıkların oranı', '%', 100, [
      (0, 400),
      (50, 0),
      (100, -200),
    ]),
    17: CarbonNumericInput('Günlük video izleme süren', 'saat/gün', 24, [
      (0, 0),
      (0.5, 20),
      (2, 80),
      (5, 200),
    ]),
    18: CarbonNumericInput('Bulutta tuttuğun veri', 'GB', 100000, [
      (0, 0),
      (5, 10),
      (55, 50),
      (250, 150),
    ]),
    19: CarbonNumericInput('Cihazını kaç yılda bir yeniliyorsun?', 'yıl', 10, [
      (0.5, 1200),
      (1, 600),
      (2.5, 250),
      (4.5, 50),
      (10, 0),
    ], minimum: 0.5),
    20: CarbonNumericInput('Okunmamış e-posta sayın', 'adet', 1000000, [
      (0, 0),
      (5000, 20),
      (20000, 80),
    ]),
  };
}
