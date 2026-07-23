enum CarbonFootprintTier {
  natureGuardian('Doğa Koruyucusu'),
  openToGrowth('Gelişime Açık'),
  carbonMonster('Karbon Canavarı');

  const CarbonFootprintTier(this.label);

  final String label;
}

class CarbonAnswerOption {
  const CarbonAnswerOption({required this.label, required this.kgOfCo2});

  final String label;
  final int kgOfCo2;
}

class CarbonQuestion {
  const CarbonQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.options,
  });

  final int id;
  final String category;
  final String question;
  final List<CarbonAnswerOption> options;
}

class CarbonFootprintResult {
  const CarbonFootprintResult({required this.annualKg, required this.tier});

  final int annualKg;
  final CarbonFootprintTier tier;

  double get annualTons => annualKg / 1000;
}

abstract final class CarbonFootprintCalculator {
  static CarbonFootprintResult calculate({
    required List<CarbonQuestion> questions,
    required Map<int, int> selectedOptionIndexes,
  }) {
    if (selectedOptionIndexes.length != questions.length) {
      throw StateError('Karbon hesabı için tüm sorular yanıtlanmalıdır.');
    }

    var totalKg = 0;
    for (final question in questions) {
      final selectedIndex = selectedOptionIndexes[question.id];
      if (selectedIndex == null ||
          selectedIndex < 0 ||
          selectedIndex >= question.options.length) {
        throw StateError('${question.id}. soru için geçerli bir yanıt yok.');
      }
      totalKg += question.options[selectedIndex].kgOfCo2;
    }

    return CarbonFootprintResult(annualKg: totalKg, tier: tierForKg(totalKg));
  }

  static CarbonFootprintTier tierForKg(int annualKg) {
    if (annualKg < 4000) {
      return CarbonFootprintTier.natureGuardian;
    }
    if (annualKg <= 7000) {
      return CarbonFootprintTier.openToGrowth;
    }
    return CarbonFootprintTier.carbonMonster;
  }
}

const carbonQuestions = <CarbonQuestion>[
  CarbonQuestion(
    id: 1,
    category: 'Ulaşım ve Seyahat',
    question: 'İşe/Okula günlük ana ulaşım yöntemin nedir?',
    options: [
      CarbonAnswerOption(label: 'Yürüyüş / Bisiklet', kgOfCo2: 0),
      CarbonAnswerOption(label: 'Toplu Taşıma / Metro', kgOfCo2: 300),
      CarbonAnswerOption(label: 'Elektrikli Araç / Scooter', kgOfCo2: 150),
      CarbonAnswerOption(label: 'Benzinli / Dizel Otomobil', kgOfCo2: 1200),
    ],
  ),
  CarbonQuestion(
    id: 2,
    category: 'Ulaşım ve Seyahat',
    question: 'Bireysel aracınla veya taksiyle haftada kaç km yol yaparsın?',
    options: [
      CarbonAnswerOption(label: 'Araç kullanmam', kgOfCo2: 0),
      CarbonAnswerOption(label: '0 - 50 km', kgOfCo2: 200),
      CarbonAnswerOption(label: '50 - 150 km', kgOfCo2: 600),
      CarbonAnswerOption(label: '150 km ve üzeri', kgOfCo2: 1500),
    ],
  ),
  CarbonQuestion(
    id: 3,
    category: 'Ulaşım ve Seyahat',
    question: 'Yılda kaç kez uçakla seyahat edersin?',
    options: [
      CarbonAnswerOption(label: 'Hiç', kgOfCo2: 0),
      CarbonAnswerOption(label: '1-2 kez (Kısa mesafe)', kgOfCo2: 500),
      CarbonAnswerOption(label: '3-5 kez', kgOfCo2: 1500),
      CarbonAnswerOption(label: 'Sürekli uçuyorum', kgOfCo2: 3000),
    ],
  ),
  CarbonQuestion(
    id: 4,
    category: 'Ulaşım ve Seyahat',
    question: 'Şehirlerarası seyahatlerde (Kayseri-Şanlıurfa gibi) tercihiniz?',
    options: [
      CarbonAnswerOption(label: 'Tren / YHT', kgOfCo2: 100),
      CarbonAnswerOption(label: 'Otobüs', kgOfCo2: 250),
      CarbonAnswerOption(label: 'Ortak Araç (Carpooling)', kgOfCo2: 400),
      CarbonAnswerOption(label: 'Tek başıma özel araç', kgOfCo2: 900),
    ],
  ),
  CarbonQuestion(
    id: 5,
    category: 'Beslenme ve Tüketim',
    question: 'Temel beslenme tarzın hangisi?',
    options: [
      CarbonAnswerOption(label: 'Vegan', kgOfCo2: 500),
      CarbonAnswerOption(label: 'Vejetaryen', kgOfCo2: 700),
      CarbonAnswerOption(label: 'Haftada 1-2 gün et', kgOfCo2: 1200),
      CarbonAnswerOption(label: 'Her gün et tüketirim', kgOfCo2: 2500),
    ],
  ),
  CarbonQuestion(
    id: 6,
    category: 'Beslenme ve Tüketim',
    question: 'Gıdalarını nereden temin edersin?',
    options: [
      CarbonAnswerOption(label: 'Sadece yerel üretici ve pazar', kgOfCo2: 100),
      CarbonAnswerOption(label: 'Karışık (Market ve Pazar)', kgOfCo2: 300),
      CarbonAnswerOption(
        label: 'Çoğunlukla ithal/paketlenmiş zincir market ürünleri',
        kgOfCo2: 700,
      ),
    ],
  ),
  CarbonQuestion(
    id: 7,
    category: 'Beslenme ve Tüketim',
    question: 'Dışarıdan paket servis (kurye) sipariş sıklığın?',
    options: [
      CarbonAnswerOption(label: 'Ayda 1-2 kez', kgOfCo2: 50),
      CarbonAnswerOption(label: 'Haftada 1-2 kez', kgOfCo2: 200),
      CarbonAnswerOption(label: 'Neredeyse her gün', kgOfCo2: 600),
    ],
  ),
  CarbonQuestion(
    id: 8,
    category: 'Beslenme ve Tüketim',
    question: 'Gıda israfı (çöpe atılan yemek) durumun nedir?',
    options: [
      CarbonAnswerOption(
        label: 'Hiç atmam, kalanları değerlendiririm',
        kgOfCo2: 0,
      ),
      CarbonAnswerOption(
        label: 'Haftada 1-2 porsiyon bozulur/dökülür',
        kgOfCo2: 150,
      ),
      CarbonAnswerOption(label: 'Sık sık yemekleri çöpe atarım', kgOfCo2: 400),
    ],
  ),
  CarbonQuestion(
    id: 9,
    category: 'Ev ve Enerji',
    question: 'Evinin ısınma altyapısı nedir?',
    options: [
      CarbonAnswerOption(label: 'Güneş Enerjisi / Isı Pompası', kgOfCo2: 100),
      CarbonAnswerOption(label: 'Doğalgaz / Kombi', kgOfCo2: 800),
      CarbonAnswerOption(label: 'Merkezi Kömür / Soba', kgOfCo2: 1500),
      CarbonAnswerOption(label: 'Elektrikli Isıtıcılar', kgOfCo2: 1200),
    ],
  ),
  CarbonQuestion(
    id: 10,
    category: 'Ev ve Enerji',
    question: 'Evindeki yalıtım (izolasyon) durumu nasıl?',
    options: [
      CarbonAnswerOption(
        label: 'Çok iyi (Yeni bina/Mantolama var)',
        kgOfCo2: 100,
      ),
      CarbonAnswerOption(label: 'Orta seviye', kgOfCo2: 400),
      CarbonAnswerOption(
        label: 'Kötü (Pencerelerden soğuk giriyor)',
        kgOfCo2: 800,
      ),
    ],
  ),
  CarbonQuestion(
    id: 11,
    category: 'Ev ve Enerji',
    question: 'Beyaz eşyalarının enerji sınıfı?',
    options: [
      CarbonAnswerOption(label: 'Hepsi A+++ / Yeni nesil', kgOfCo2: 100),
      CarbonAnswerOption(label: 'Karışık', kgOfCo2: 300),
      CarbonAnswerOption(
        label: 'Eski tip, çok elektrik harcayan cihazlar',
        kgOfCo2: 600,
      ),
    ],
  ),
  CarbonQuestion(
    id: 12,
    category: 'Ev ve Enerji',
    question: 'Yaz aylarında klima kullanımın?',
    options: [
      CarbonAnswerOption(label: 'Klima kullanmam', kgOfCo2: 0),
      CarbonAnswerOption(
        label: 'Sadece çok sıcak günlerde birkaç saat',
        kgOfCo2: 150,
      ),
      CarbonAnswerOption(label: 'Tüm gün/gece açık kalır', kgOfCo2: 500),
    ],
  ),
  CarbonQuestion(
    id: 13,
    category: 'Alışveriş ve Atık',
    question: 'Giyim alışverişi sıklığın (Hızlı Moda)?',
    options: [
      CarbonAnswerOption(
        label: 'Sadece ihtiyacım olunca veya 2. el alırım',
        kgOfCo2: 50,
      ),
      CarbonAnswerOption(label: 'Birkaç ayda bir mağaza gezerim', kgOfCo2: 200),
      CarbonAnswerOption(label: 'Her ay yeni kıyafetler alırım', kgOfCo2: 600),
    ],
  ),
  CarbonQuestion(
    id: 14,
    category: 'Alışveriş ve Atık',
    question: 'Tek kullanımlık plastik (pet şişe, bardak) kullanımın?',
    options: [
      CarbonAnswerOption(
        label: 'Matara ve termos kullanırım, asla almam',
        kgOfCo2: 0,
      ),
      CarbonAnswerOption(
        label: 'Haftada birkaç kez zorunlu kalınca',
        kgOfCo2: 150,
      ),
      CarbonAnswerOption(
        label: 'Her gün dışarıdan pet şişe su / kahve alırım',
        kgOfCo2: 500,
      ),
    ],
  ),
  CarbonQuestion(
    id: 15,
    category: 'Alışveriş ve Atık',
    question: 'Kağıt ve karton tüketimin?',
    options: [
      CarbonAnswerOption(label: 'Her şeyim dijitaldir', kgOfCo2: 20),
      CarbonAnswerOption(
        label: 'Gerektikçe defter/çıktı kullanırım',
        kgOfCo2: 100,
      ),
      CarbonAnswerOption(
        label: 'Sürekli kağıt havlu, çıktı ve not defteri harcarım',
        kgOfCo2: 300,
      ),
    ],
  ),
  CarbonQuestion(
    id: 16,
    category: 'Alışveriş ve Atık',
    question: "EcoVision'dan önce atıklarını ayırıyor muydun?",
    options: [
      CarbonAnswerOption(
        label: 'Tamamını titizlikle ayırırdım (-200 kg *Bonus*)',
        kgOfCo2: -200,
      ),
      CarbonAnswerOption(
        label: 'Sadece plastik ve kağıtları ayırırdım',
        kgOfCo2: 0,
      ),
      CarbonAnswerOption(
        label: 'Her şeyi aynı çöp kutusuna atardım',
        kgOfCo2: 400,
      ),
    ],
  ),
  CarbonQuestion(
    id: 17,
    category: 'Dijital Karbon Ayak İzi',
    question: 'Günlük video streaming (Netflix, YouTube vb.) süren?',
    options: [
      CarbonAnswerOption(label: '1 saatten az', kgOfCo2: 20),
      CarbonAnswerOption(label: '1 - 3 saat arası', kgOfCo2: 80),
      CarbonAnswerOption(
        label: '3 saatten fazla (Yüksek çözünürlükte)',
        kgOfCo2: 200,
      ),
    ],
  ),
  CarbonQuestion(
    id: 18,
    category: 'Dijital Karbon Ayak İzi',
    question: 'Bulut depolama (Drive, iCloud) kullanımın?',
    options: [
      CarbonAnswerOption(
        label: 'Sadece gerekli dosyalar (< 10 GB)',
        kgOfCo2: 10,
      ),
      CarbonAnswerOption(
        label: 'Fotoğraf ve yedeklemeler aktif (10 - 100 GB)',
        kgOfCo2: 50,
      ),
      CarbonAnswerOption(
        label: 'Her şeyi bulutta tutarım (> 100 GB)',
        kgOfCo2: 150,
      ),
    ],
  ),
  CarbonQuestion(
    id: 19,
    category: 'Dijital Karbon Ayak İzi',
    question: 'Telefon / Bilgisayar yenileme sıklığın?',
    options: [
      CarbonAnswerOption(
        label: 'Bozulana kadar (4-5 yıl) kullanırım',
        kgOfCo2: 50,
      ),
      CarbonAnswerOption(
        label: '2-3 yılda bir model yükseltirim',
        kgOfCo2: 250,
      ),
      CarbonAnswerOption(label: 'Her yıl en yeni modeli alırım', kgOfCo2: 600),
    ],
  ),
  CarbonQuestion(
    id: 20,
    category: 'Dijital Karbon Ayak İzi',
    question: 'E-posta kutunun durumu?',
    options: [
      CarbonAnswerOption(
        label: 'Düzenli temizlerim, gereksiz abonelikleri iptal ederim',
        kgOfCo2: 0,
      ),
      CarbonAnswerOption(label: 'Arada sırada toplu silerim', kgOfCo2: 20),
      CarbonAnswerOption(
        label: 'On binlerce okunmamış spam mailim duruyor',
        kgOfCo2: 80,
      ),
    ],
  ),
];
