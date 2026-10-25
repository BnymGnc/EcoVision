import 'dart:convert';
import 'package:ecovision/models/carbon_footprint.dart';
import 'package:ecovision/models/carbon_numeric_input.dart';
import 'package:ecovision/models/quest_progress.dart';
import 'package:ecovision/screens/home_screen.dart';
import 'package:ecovision/screens/missions_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  for (final size in [
    const Size(930, 830),
    const Size(320, 480),
    const Size(390, 844),
    const Size(700, 320),
  ]) {
    testWidgets('scanner stays bounded at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const ScanningOverlay(
                message: 'Yapay zeka atığı tanıyor...',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('EcoVision AI Tarayıcı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final kind in AppThemeKind.values) {
    testWidgets('scanner fits the visible screen and theme: $kind', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = AppThemes.forKind(kind);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.8),
            ),
            child: const ScanningOverlay(
              message:
                  'Yapay zeka fotoğrafını güvenli biçimde analiz ediyor...',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      final surface = tester.widget<Material>(
        find.byKey(const ValueKey('scanner-surface')),
      );
      expect(surface.color, theme.colorScheme.surface);
      final sweep = tester.getRect(find.byKey(const ValueKey('scanner-sweep')));
      final status = tester.getRect(
        find.text('Yapay zeka fotoğrafını güvenli biçimde analiz ediyor...'),
      );
      expect(sweep.top, greaterThanOrEqualTo(0));
      expect(sweep.bottom, lessThanOrEqualTo(status.top));
      expect(status.bottom, lessThanOrEqualTo(480));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
    'legacy Render route conversion 400 falls back and pages without hiding entries',
    () async {
      final paths = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/login') return _loginResponse();
          paths.add(request.url.path);
          if (request.url.path == '/api/map-pins/search') {
            return http.Response(
              jsonEncode({'message': 'İstek parametresi geçersiz'}),
              400,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.path, '/api/map-pins/nearby');
          final limit = int.parse(request.url.queryParameters['limit']!);
          return http.Response(
            jsonEncode(
              List.generate(
                limit,
                (i) => {'id': i + 1, 'latitude': 37.17, 'longitude': 38.8},
              ),
            ),
            200,
          );
        }),
      );
      api.setRememberMe(false);
      await api.login(email: 'test@ecovision.invalid', password: 'unit-test');
      final first = await api.searchDoaPoints(latitude: 37.17, longitude: 38.8);
      expect(first.items, hasLength(100));
      expect(first.hasMore, isTrue);
      expect(first.totalIsExact, isFalse);
      final second = await api.searchDoaPoints(
        latitude: 37.17,
        longitude: 38.8,
        offset: 100,
      );
      expect(second.items.first.id, 101);
      expect(second.items.last.id, 200);
      expect(paths, [
        '/api/map-pins/search',
        '/api/map-pins/nearby',
        '/api/map-pins/nearby',
      ]);
    },
  );

  test(
    'business validation 400 never falls back to a different route',
    () async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/login') return _loginResponse();
          calls++;
          return http.Response(jsonEncode({'message': 'Invalid radius'}), 400);
        }),
      );
      api.setRememberMe(false);
      await api.login(email: 'test@ecovision.invalid', password: 'unit-test');
      await expectLater(
        api.searchDoaPoints(latitude: 37, longitude: 38),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    },
  );

  test('all twenty questions accept validated numeric refinements', () {
    expect(CarbonNumericInputs.fields.length, 20);
    final choices = {for (final q in carbonQuestions) q.id: 0};
    for (final q in carbonQuestions) {
      final spec = CarbonNumericInputs.fields[q.id]!;
      final value = spec.minimum > 0 ? spec.minimum : 1.0;
      final result = CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: choices,
        numericAnswers: {q.id: value},
      );
      expect(result.consumptionAdjusted, isTrue);
      expect(result.annualKg, greaterThanOrEqualTo(0));
      expect(spec.validate('NaN'), isNotNull);
      expect(spec.validate('-1'), isNotNull);
      expect(spec.validate('${spec.maximum + 1}'), isNotNull);
    }
  });

  test(
    '250 km overrides the range answer and avoids duplicate car estimates',
    () {
      final selections = {
        for (final q in carbonQuestions) q.id: 0,
        1: 3,
        2: 3,
        4: 3,
      };
      final result = CarbonFootprintCalculator.calculate(
        questions: carbonQuestions,
        selectedOptionIndexes: selections,
        numericAnswers: const {2: 250},
      );
      expect(
        result.annualKg,
        (900 + 250 * 52 * CarbonNumericInputs.carKgPerKm).round(),
      );
    },
  );

  test(
    'numeric answer can replace a quantitative choice, not a transport method',
    () {
      final choices = {
        for (final q in carbonQuestions)
          if (q.id != 2) q.id: 0,
      };
      expect(
        CarbonFootprintCalculator.calculate(
          questions: carbonQuestions,
          selectedOptionIndexes: choices,
          numericAnswers: const {2: 250},
        ).annualKg,
        greaterThan(1000),
      );
      choices.remove(1);
      expect(
        () => CarbonFootprintCalculator.calculate(
          questions: carbonQuestions,
          selectedOptionIndexes: choices,
          numericAnswers: const {1: 20, 2: 250},
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    '200 missions can scroll, filter, refresh and retain cards on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _LongQuestApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: MissionsScreen(points: 0, apiService: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      final scroll = tester.state<ScrollableState>(vertical);
      // Large jumps can skip a dynamically measured sliver child. Traverse
      // the list with viewport-sized gestures, then settle the final extent.
      for (
        var i = 0;
        i < 600 && find.byKey(const ValueKey(200)).evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(find.text('Görev 200'), findsOneWidget);
      expect(tester.takeException(), isNull);
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tümü'));
      await tester.pumpAndSettle();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Görev 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

http.Response _loginResponse() => http.Response(
  jsonEncode({
    'accessToken': 'unit-test-access',
    'refreshToken': 'unit-test-refresh',
    'user': {
      'id': 1,
      'name': 'Test',
      'surname': 'User',
      'email': 'test@ecovision.invalid',
      'totalPoints': 0,
    },
  }),
  200,
);

class _LongQuestApi extends ApiService {
  @override
  Future<List<QuestProgress>> fetchQuests() async => List.generate(
    200,
    (i) => QuestProgress(
      questId: i + 1,
      progressId: i + 1,
      code: 'test-$i',
      title: 'Görev ${i + 1}',
      description:
          'Atık azaltma ve yeniden kullanım alışkanlığını sürdür. ' *
          (1 + i % 4),
      rewardPoints: 100,
      targetAmount: 100000,
      schedule: 'DAILY',
      domain: 'RECYCLING',
      currentAmount: 99999,
      completed: i % 3 == 0,
      claimed: i % 4 == 0,
      checkInAvailable: i % 2 == 0,
    ),
  );
}
