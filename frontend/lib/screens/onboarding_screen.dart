import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'main_tab_navigator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.apiService, super.key});

  static const preferencePrefix = 'hasSeenOnboarding';

  final ApiService apiService;

  static String preferenceKey(int userId) => '${preferencePrefix}_$userId';

  static Future<bool> hasSeenForUser(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(preferenceKey(userId)) ?? false;
  }

  static Future<void> markSeenForUser(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(preferenceKey(userId), true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page >= _pages.length - 1) return;
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final user = widget.apiService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _finishing = false);
      return;
    }

    await OnboardingScreen.markSeenForUser(user.id);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainTabNavigator(apiService: widget.apiService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'EcoVision',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    '${_page + 1} / ${_pages.length}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _OnboardingPage(
                  key: ValueKey('onboarding-page-$index'),
                  data: _pages[index],
                  active: index == _page,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: Column(
                children: [
                  _PageIndicator(page: _page, count: _pages.length),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _page == _pages.length - 1
                        ? _GlowingStartButton(
                            key: const ValueKey('start'),
                            loading: _finishing,
                            onPressed: _finish,
                          )
                        : SizedBox(
                            key: const ValueKey('next'),
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _next,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Devam Et'),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.active, super.key});

  final _OnboardingData data;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.sizeOf(context).height - 210).clamp(500, 760),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimationPlaceholder(data: data),
            const SizedBox(height: 30),
            TweenAnimationBuilder<double>(
              key: ValueKey('title-${data.pageNumber}-$active'),
              tween: Tween(begin: 0, end: active ? 1 : 0),
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: child,
                ),
              ),
              child: Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 176,
              child: active
                  ? AnimatedTextKit(
                      key: ValueKey('story-${data.pageNumber}'),
                      isRepeatingAnimation: false,
                      totalRepeatCount: 1,
                      displayFullTextOnTap: true,
                      animatedTexts: [
                        TypewriterAnimatedText(
                          data.body,
                          textAlign: TextAlign.center,
                          speed: const Duration(milliseconds: 22),
                          textStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.48,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimationPlaceholder extends StatelessWidget {
  const _AnimationPlaceholder({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    // Replace this placeholder for page 1 with:
    // Lottie.asset('assets/animations/onboarding_1.json')
    // Replace this placeholder for page 2 with:
    // Lottie.asset('assets/animations/onboarding_2.json')
    // Replace this placeholder for page 3 with:
    // Lottie.asset('assets/animations/onboarding_3.json')
    // Replace this placeholder for page 4 with:
    // Lottie.asset('assets/animations/onboarding_4.json')
    return Container(
      width: MediaQuery.sizeOf(context).width.clamp(240, 330),
      height: MediaQuery.sizeOf(context).width.clamp(240, 330),
      decoration: BoxDecoration(
        color: data.color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.color.withAlpha(80), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(data.icon, size: 116, color: data.color),
          Positioned(
            right: 34,
            top: 32,
            child: Icon(data.accentIcon, size: 40, color: data.color),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: index == page ? 34 : 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: index == page ? colors.primary : colors.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _GlowingStartButton extends StatelessWidget {
  const _GlowingStartButton({
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primary.withAlpha(80),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.rocket_launch_rounded),
        label: const Text('Hemen Başla'),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.pageNumber,
    required this.title,
    required this.body,
    required this.icon,
    required this.accentIcon,
    required this.color,
  });

  final int pageNumber;
  final String title;
  final String body;
  final IconData icon;
  final IconData accentIcon;
  final Color color;
}

const _pages = [
  _OnboardingData(
    pageNumber: 1,
    title: 'Merhaba Kahraman! 🌍',
    body:
        'Ben Dünya... Senin evin. Son zamanlarda üzerimdeki atık yükü '
        'giderek ağırlaşıyor ve biraz hastayım. Ama umutsuz değilim, '
        "çünkü sen buradasın! EcoVision'a hoş geldin. Birlikte doğayı "
        'iyileştirmeye hazır mısın?',
    icon: Icons.public_rounded,
    accentIcon: Icons.favorite_rounded,
    color: Color(0xFF43A047),
  ),
  _OnboardingData(
    pageNumber: 2,
    title: 'Gücünü Keşfet! 🔍',
    body:
        'Beni kurtarmak sandığından daha kolay. Telefonunun kamerasını aç '
        've karşılaştığın atıkları tara! Gelişmiş yapay zekam sayesinde '
        'o atığın hangi geri dönüşüm kutusuna gitmesi gerektiğini sana '
        'anında söyleyeceğim.',
    icon: Icons.document_scanner_rounded,
    accentIcon: Icons.auto_awesome_rounded,
    color: Color(0xFF1976D2),
  ),
  _OnboardingData(
    pageNumber: 3,
    title: 'İyiliğin Ödüllendirilecek! ⭐',
    body:
        "Yaptığın her doğru hamle için sana 'Eco Puan' vereceğim. Bu "
        "puanlarla Eco-Market'te karakterini geliştirebilir, yeni rozetler "
        'kazanabilir ve şehrindeki liderlik tablosunda zirveye '
        'tırmanabilirsin.',
    icon: Icons.emoji_events_rounded,
    accentIcon: Icons.stars_rounded,
    color: Color(0xFFF9A825),
  ),
  _OnboardingData(
    pageNumber: 4,
    title: 'Birlikte Daha Güçlüyüz! 🤝',
    body:
        'Bu savaşta yalnız değilsin. Arkadaşlarınla şifreli gruplarını kur, '
        'ortak atık toplama görevlerine katıl ve mahalleni temizle. Doğanın '
        'kahramanları arasına katılmaya hazırsan... Hadi, maceramız '
        'başlasın!',
    icon: Icons.groups_rounded,
    accentIcon: Icons.volunteer_activism_rounded,
    color: Color(0xFFE76F51),
  ),
];
