import 'dart:async';

import 'package:ecovision/models/academy_module.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/screens/academy_quiz_screen.dart';
import 'package:ecovision/screens/eco_market_screen.dart';
import 'package:ecovision/screens/settings_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  testWidgets(
    'privacy is single-flight before haptics and uses saved visibility',
    (tester) async {
      final api = _InteractionApi();
      await _pumpUi(tester, SettingsScreen(apiService: api));
      final haptics = _pauseHaptics(tester);
      final privacy = find.widgetWithText(SwitchListTile, 'Gizli Profil');
      final change = tester.widget<SwitchListTile>(privacy).onChanged!;

      change(true);
      change(false);
      await tester.pump();

      expect(api.visibilityRequests, isEmpty);
      expect(tester.widget<SwitchListTile>(privacy).onChanged, isNull);

      haptics.complete();
      await tester.pump();
      expect(api.visibilityRequests, ['FRIENDS_ONLY']);
      change(false);
      await tester.pump();
      expect(api.visibilityRequests, hasLength(1));

      api.visibilityResponses.single.complete(_user(visibility: 'PUBLIC'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(privacy).value, isFalse);
      expect(tester.widget<SwitchListTile>(privacy).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'privacy failure restores the last saved value and allows retry',
    (tester) async {
      final api = _InteractionApi(user: _user(visibility: 'FRIENDS_ONLY'));
      await _pumpUi(tester, SettingsScreen(apiService: api));
      final privacy = find.widgetWithText(SwitchListTile, 'Gizli Profil');
      expect(tester.widget<SwitchListTile>(privacy).value, isTrue);

      tester.widget<SwitchListTile>(privacy).onChanged!(false);
      await tester.pump();
      api.visibilityResponses.single.completeError(
        const ApiException('Privacy save failed'),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(privacy).value, isTrue);
      expect(tester.widget<SwitchListTile>(privacy).onChanged, isNotNull);
      expect(find.text('Privacy save failed'), findsOneWidget);

      tester.widget<SwitchListTile>(privacy).onChanged!(false);
      await tester.pump();
      expect(api.visibilityRequests, ['PUBLIC', 'PUBLIC']);
      api.visibilityResponses.last.complete(_user(visibility: 'PUBLIC'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(privacy).value, isFalse);
      expect(tester.widget<SwitchListTile>(privacy).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('privacy response after disposal does not update the screen', (
    tester,
  ) async {
    final api = _InteractionApi();
    await _pumpUi(tester, SettingsScreen(apiService: api));
    final privacy = find.widgetWithText(SwitchListTile, 'Gizli Profil');
    tester.widget<SwitchListTile>(privacy).onChanged!(true);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    api.visibilityResponses.single.complete(_user(visibility: 'FRIENDS_ONLY'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'market gates all purchases before haptics and while the request is pending',
    (tester) async {
      final api = _InteractionApi();
      await _pumpUi(tester, EcoMarketScreen(apiService: api));
      final haptics = _pauseHaptics(tester);
      final buyFreeze = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '250 puan'))
          .onPressed!;
      final buyFrame = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '100 puan'))
          .onPressed!;

      buyFreeze();
      buyFreeze();
      buyFrame();
      await tester.pump();

      expect(api.purchases, isEmpty);
      expect(find.byType(FilledButton), findsNWidgets(4));
      expect(
        tester
            .widgetList<FilledButton>(find.byType(FilledButton))
            .map((button) => button.onPressed),
        everyElement(isNull),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      haptics.complete();
      await tester.pump();
      expect(api.purchases, ['streak_freeze']);
      buyFrame();
      await tester.pump();
      expect(api.purchases, hasLength(1));

      api.purchaseResponses.single.complete(_user(points: 750));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(
          AlertDialog,
          'Yeni \u00f6d\u00fcl a\u00e7\u0131ld\u0131!',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Seri Dondurucu koleksiyonuna eklendi. '
          'Kalan Eko Puan\u0131n: 750.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '250 puan'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('market failure releases the gate for a later purchase', (
    tester,
  ) async {
    final api = _InteractionApi();
    await _pumpUi(tester, EcoMarketScreen(apiService: api));

    await tester.tap(find.text('100 puan'));
    await tester.pump();
    api.purchaseResponses.single.completeError(
      const ApiException('Purchase failed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Purchase failed'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('250 puan'));
    await tester.pump();
    expect(api.purchases, ['leaf_frame', 'streak_freeze']);

    api.purchaseResponses.last.complete(_user(points: 750));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final points in [0, 1000]) {
    testWidgets(
      'market fits 320px at 1.6 text scale with a $points point balance',
      (tester) async {
        final api = _InteractionApi(user: _user(points: points));
        await _pumpUi(
          tester,
          EcoMarketScreen(apiService: api),
          size: const Size(320, 640),
          textScale: 1.6,
        );
        expect(tester.takeException(), isNull);
        final scrollable = find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first;

        for (final price in [250, 100, 200, 300]) {
          final label = points == 0 ? '$price puan gerekli' : '$price puan';
          final purchase = find.widgetWithText(FilledButton, label);
          await tester.scrollUntilVisible(
            purchase,
            160,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();

          expect(purchase.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(purchase);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(640));
          expect(tester.takeException(), isNull);
        }
        expect(api.purchases, isEmpty);
      },
    );
  }

  for (final size in [const Size(320, 400), const Size(700, 360)]) {
    testWidgets(
      'quiz scrolls question/options/feedback at $size with 1.6 text scale',
      (tester) async {
        final module = _quizModule();
        await _pumpUi(
          tester,
          AcademyQuizScreen(module: module, apiService: null),
          size: size,
          textScale: 1.6,
        );

        for (var index = 0; index < module.questions.length; index++) {
          final question = module.questions[index];
          final content = find.byKey(
            const ValueKey('academy-question-content'),
          );
          final scrollable = find.descendant(
            of: content,
            matching: find.byType(Scrollable),
          );
          final confirm = find.widgetWithText(
            FilledButton,
            'Cevab\u0131 Onayla',
          );
          expect(tester.takeException(), isNull);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

          final choice = index == 0
              ? question.options.last
              : question.options.first;
          await tester.scrollUntilVisible(
            find.text(choice),
            140,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(find.text(choice).hitTestable(), findsOneWidget);
          await tester.tap(find.text(choice));
          await tester.pumpAndSettle();
          expect(
            tester.state<ScrollableState>(scrollable).position.pixels,
            greaterThan(0),
          );
          expect(confirm.hitTestable(), findsOneWidget);
          final buttonRect = tester.getRect(confirm);
          expect(buttonRect.top, greaterThanOrEqualTo(0));
          expect(buttonRect.bottom, lessThanOrEqualTo(size.height));

          await tester.tap(confirm);
          await tester.pumpAndSettle();
          final feedback = find.text(
            index == 0
                ? 'Do\u011fru cevap: ${question.options.first}'
                : 'Harika, do\u011fru cevap!',
          );
          await tester.scrollUntilVisible(
            feedback,
            140,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(feedback.hitTestable(), findsOneWidget);
          final next = find.widgetWithText(
            FilledButton,
            index == module.questions.length - 1
                ? 'Sonucu G\u00f6r'
                : 'Sonraki Soru',
          );
          expect(next.hitTestable(), findsOneWidget);
          expect(tester.getRect(next), buttonRect);
          expect(tester.takeException(), isNull);

          await tester.tap(next);
          await tester.pumpAndSettle();
        }

        expect(find.text('Mod\u00fcl\u00fc Tamamlad\u0131n!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpUi(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(900, 1600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = ThemeController();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    theme.dispose();
  });
  await tester.pumpWidget(
    ThemeScope(
      controller: theme,
      child: MaterialApp(
        theme: AppThemes.forKind(AppThemeKind.forest),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Completer<void> _pauseHaptics(WidgetTester tester) {
  final gate = Completer<void>();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') await gate.future;
      return null;
    },
  );
  addTearDown(() {
    if (!gate.isCompleted) gate.complete();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
  });
  return gate;
}

UserProfile _user({String visibility = 'PUBLIC', int points = 1000}) =>
    UserProfile(
      id: 1,
      name: 'Ada',
      surname: 'Green',
      email: 'ada@ecovision.test',
      totalPoints: points,
      role: 'USER',
      city: 'Ankara',
      ownedMarketItems: const {},
      profileVisibility: visibility,
    );

class _InteractionApi extends ApiService {
  _InteractionApi({UserProfile? user}) : _current = user ?? _user();

  UserProfile _current;
  final visibilityRequests = <String>[];
  final visibilityResponses = <Completer<UserProfile>>[];
  final purchases = <String>[];
  final purchaseResponses = <Completer<UserProfile>>[];

  @override
  UserProfile get currentUser => _current;

  @override
  Future<UserProfile> fetchCurrentUser() async => _current;

  @override
  Future<UserProfile> updateProfileVisibility(String visibility) async {
    visibilityRequests.add(visibility);
    final response = Completer<UserProfile>();
    visibilityResponses.add(response);
    return _current = await response.future;
  }

  @override
  Future<UserProfile> purchaseMarketItem(String itemId) async {
    purchases.add(itemId);
    final response = Completer<UserProfile>();
    purchaseResponses.add(response);
    return _current = await response.future;
  }
}

AcademyModule _quizModule() => AcademyModule(
  categoryId: 'modul-1',
  title: 'Layout test',
  contentBody: 'Recycling guide fixture.',
  questions: List.generate(
    3,
    (index) => AcademyQuestion(
      questionText:
          'Question ${index + 1}: How should packaging be prepared before '
          'recycling so that food residues do not contaminate the other '
          'materials in the collection container?',
      options: [
        'Correct choice ${index + 1}: Empty the packaging and follow the local '
            'collection rules.',
        'Second choice ${index + 1}: Mix food residues with the other collected '
            'materials.',
        'Third choice ${index + 1}: Put every kind of packaging in the same '
            'container.',
        'Last choice ${index + 1}: Leave the packaging full and place it beside '
            'the container.',
      ],
      correctOptionIndex: 0,
    ),
  ),
);
