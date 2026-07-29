import 'package:ecovision/main.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/screens/login_screen.dart';
import 'package:ecovision/screens/onboarding_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('uygulama her zaman giriş ekranında açılır', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      EcoVisionApp(
        apiService: _NoSessionApiService(),
        themeController: ThemeController(),
      ),
    );
    expect(find.text('EcoVision'), findsOneWidget);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("EcoVision'a Hoş Geldin"), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  test('onboarding tercihi her kullanıcı için ayrı saklanır', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await OnboardingScreen.hasSeenForUser(41), isFalse);
    expect(await OnboardingScreen.hasSeenForUser(72), isFalse);

    await OnboardingScreen.markSeenForUser(41);

    expect(await OnboardingScreen.hasSeenForUser(41), isTrue);
    expect(await OnboardingScreen.hasSeenForUser(72), isFalse);
    expect(OnboardingScreen.preferenceKey(41), 'hasSeenOnboarding_41');
  });

  testWidgets('ilk başarılı girişten sonra onboarding gösterilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final apiService = _LoginApiService();
    final themeController = ThemeController();

    await tester.pumpWidget(
      ThemeScope(
        controller: themeController,
        child: MaterialApp(home: LoginScreen(apiService: apiService)),
      ),
    );
    await tester.pumpAndSettle();

    await _submitLogin(tester);

    expect(find.text('Merhaba Kahraman! 🌍'), findsOneWidget);
    expect(await OnboardingScreen.hasSeenForUser(314), isFalse);

    for (var page = 0; page < 3; page++) {
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Hemen Başla'), findsOneWidget);

    await tester.tap(find.text('Hemen Başla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(await OnboardingScreen.hasSeenForUser(314), isTrue);
    expect(find.text('Tarayıcı'), findsOneWidget);
  });

  testWidgets('onboarding görmüş kullanıcı doğrudan ana ekrana geçer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      OnboardingScreen.preferenceKey(314): true,
    });
    final apiService = _LoginApiService();
    final themeController = ThemeController();

    await tester.pumpWidget(
      ThemeScope(
        controller: themeController,
        child: MaterialApp(home: LoginScreen(apiService: apiService)),
      ),
    );
    await tester.pumpAndSettle();

    await _submitLogin(tester);

    expect(find.text('Tarayıcı'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'kahraman@ecovision.test',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Test123!');
  await tester.tap(find.text('Giriş Yap'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

class _LoginApiService extends ApiService {
  static const _user = UserProfile(
    id: 314,
    name: 'Dünya',
    surname: 'Kahramanı',
    email: 'kahraman@ecovision.test',
    totalPoints: 0,
    role: 'USER',
    city: 'Şanlıurfa',
    ownedMarketItems: {},
  );

  @override
  UserProfile? get currentUser => _user;

  @override
  Future<void> loadStoredSession() async {}

  @override
  Future<bool> login({required String email, required String password}) async {
    return true;
  }
}

class _NoSessionApiService extends ApiService {
  @override
  UserProfile? get currentUser => null;

  @override
  Future<void> loadStoredSession() async {}
}
