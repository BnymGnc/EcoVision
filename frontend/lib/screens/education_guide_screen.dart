import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/constants.dart';

class EducationGuideScreen extends StatefulWidget {
  const EducationGuideScreen({super.key});

  @override
  State<EducationGuideScreen> createState() => _EducationGuideScreenState();
}

class _EducationGuideScreenState extends State<EducationGuideScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Atık Ansiklopedisi')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atmadan Önce Öğren',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Geri dönüşüm bilgileri arasında kaydırarak ilerle.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ChoiceChip(
                  selected: _page == index,
                  onSelected: (_) => _goTo(index),
                  avatar: Icon(_categories[index].icon, size: 17),
                  label: Text(_categories[index].title),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _categories.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 240),
                    padding: EdgeInsets.fromLTRB(
                      6,
                      index == _page ? 0 : 12,
                      6,
                      index == _page ? 12 : 24,
                    ),
                    child: _LearningCard(category: _categories[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _categories.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _page == index ? 24 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _page == index
                          ? colors.primary
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  const _LearningCard({required this.category});

  final _WasteCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 154,
              width: double.infinity,
              decoration: BoxDecoration(
                color: category.color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LottieBuilder.network(
                AppConstants.loadingLottieUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(category.icon, size: 72, color: category.color),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              category.title.toUpperCase(),
              style: TextStyle(
                color: category.color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              category.impact,
              style: const TextStyle(
                fontSize: 25,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.summary,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (final rule in category.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: category.color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rule)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_rounded, color: colors.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.warning,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WasteCategory {
  const _WasteCategory({
    required this.title,
    required this.summary,
    required this.impact,
    required this.rules,
    required this.warning,
    required this.icon,
    required this.color,
  });

  final String title;
  final String summary;
  final String impact;
  final List<String> rules;
  final String warning;
  final IconData icon;
  final Color color;
}

const _categories = [
  _WasteCategory(
    title: 'Plastik Atıklar',
    summary: 'Ambalajı boşalt, hafifçe durula ve plastik kodunu kontrol et.',
    impact:
        'Doğanın Sessiz Düşmanı. Bir pet şişenin doğada yok olması 400 yıl sürer.',
    rules: [
      'Şişe ve kapları geri dönüşümden önce durula.',
      'Yerel tesis kabul ediyorsa kapakları şişeye takılı bırak.',
      'Poşet ve plastik filmleri özel toplama noktalarına götür.',
    ],
    warning:
        'Kirli ve karışık plastikler tüm geri dönüşüm partisini bozabilir.',
    icon: Icons.local_drink_outlined,
    color: Color(0xFF1976D2),
  ),
  _WasteCategory(
    title: 'Cam Atıklar',
    summary:
        'Doğru ayrıştırılan cam, kalite kaybetmeden tekrar tekrar kullanılabilir.',
    impact:
        'Sonsuz Döngü. Cam %100 geri dönüştürülebilir! Doğaya atılan bir cam ise 4000 yılda yok olur.',
    rules: [
      'Kavanoz ve şişeleri boşaltıp hafifçe durula.',
      'Yerel kutular gerektiriyorsa camı rengine göre ayır.',
      'Toplama kurallarına göre mantar ve kapakları çıkar.',
    ],
    warning: 'Ayna, seramik ve bardaklar ambalaj camından ayrı toplanmalıdır.',
    icon: Icons.wine_bar_outlined,
    color: Color(0xFF00897B),
  ),
  _WasteCategory(
    title: 'Elektronik (E-Atık)',
    summary: 'Kişisel verilerini korurken değerli metalleri geri kazandır.',
    impact:
        'Sessiz Zehir. Piller toprağa sızarsa 1 pil, 800 bin litre suyu zehirler.',
    rules: [
      'Kişisel verilerini yedekle ve güvenli biçimde sil.',
      'Cihaz uygunsa pili çıkar.',
      'Belediye e-atık noktalarını veya yetkili satıcıları kullan.',
    ],
    warning: 'Pil ve elektronik cihazları evsel atık kutusuna asla atma.',
    icon: Icons.devices_other_outlined,
    color: Color(0xFF6A1B9A),
  ),
  _WasteCategory(
    title: 'Kağıt & Karton',
    summary: 'Temiz ve kuru kağıtları diğer atıklardan ayrı tut.',
    impact: 'Geri dönüştürülen 1 ton kağıt, 17 ağacı kurtarır.',
    rules: [
      'Islak veya yağlı kağıtları geri dönüşüme karıştırma.',
      'Karton kutuları düzleştirerek hacmi azalt.',
      'Plastik bant ve ambalaj parçalarını ayır.',
    ],
    warning:
        'Termal fişler ve kirli peçeteler kağıt geri dönüşümüne uygun değildir.',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF558B2F),
  ),
  _WasteCategory(
    title: 'Bitkisel Yağlar',
    summary: 'Kullanılmış yağı soğutup kapalı bir şişede biriktir.',
    impact: '1 litre atık yağ, 1 milyon litre temiz suyu kirletir.',
    rules: [
      'Kızartma yağını soğuttuktan sonra sızdırmaz kaba aktar.',
      'Atık yağları belediyenin toplama noktalarına teslim et.',
      'Farklı yağ türlerini birbirine karıştırma.',
    ],
    warning: 'Atık yağı asla lavaboya dökme; boruları tıkar ve suyu kirletir.',
    icon: Icons.oil_barrel_outlined,
    color: Color(0xFFEF6C00),
  ),
];
