import 'package:ecovision/main.dart';
import 'package:ecovision/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ilk açılışta dört sayfalık tanıtım hikayesini gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const EcoVisionApp());
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Merhaba Kahraman! 🌍'), findsOneWidget);
    expect(find.text('Devam Et'), findsOneWidget);
    expect(await OnboardingScreen.hasSeenOnThisDevice(), isFalse);
  });

  test('tanıtım tercihi cihazda kalıcı olarak saklanır', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await OnboardingScreen.hasSeenOnThisDevice(), isFalse);
    await OnboardingScreen.markSeenOnThisDevice();
    expect(await OnboardingScreen.hasSeenOnThisDevice(), isTrue);
  });

  testWidgets('tanıtımı bitiren kullanıcı giriş ekranına yönlendirilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const EcoVisionApp());
    await tester.pumpAndSettle();

    for (var page = 0; page < 3; page++) {
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Hemen Başla'), findsOneWidget);

    await tester.tap(find.text('Hemen Başla'));
    await tester.pumpAndSettle();

    expect(await OnboardingScreen.hasSeenOnThisDevice(), isTrue);
    expect(find.text("EcoVision'a Hoş Geldin"), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });

  testWidgets('geri dönen kullanıcı tanıtımı atlayıp giriş ekranını görür', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      OnboardingScreen.preferenceKey: true,
    });

    await tester.pumpWidget(const EcoVisionApp());
    await tester.pumpAndSettle();

    expect(find.text("EcoVision'a Hoş Geldin"), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}
