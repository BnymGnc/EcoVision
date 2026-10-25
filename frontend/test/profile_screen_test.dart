import 'package:ecovision/models/scan_result.dart';
import 'package:ecovision/models/gamification_state.dart';
import 'package:ecovision/models/leaderboard_entry.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/models/social_models.dart';
import 'package:ecovision/screens/profile_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ecovision/models/login_activity.dart';
import 'package:ecovision/widgets/privacy_aware_avatar.dart';
import 'package:ecovision/widgets/profile_identity_header.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'profile displays stored annual estimate, zero, missing and failure explicitly',
    (tester) async {
      final api = _FakeApiService();
      for (final value in <num?>[4210, 0, null]) {
        api.impact = {
          'latestAnnualKg': value,
          'assessmentEvidence': 'SURVEY_ESTIMATE',
        };
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(key: ValueKey(value), apiService: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            value == null
                ? 'Hesapla'
                : value == 0
                ? '0,0 kg/yıl'
                : '4,21 t/yıl',
          ),
          findsOneWidget,
        );
        expect(find.text('Ölçülen CO₂'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      api.failImpact = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(key: const ValueKey('failure'), apiService: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar Dene'), findsOneWidget);
    },
  );
  testWidgets(
    'profil sekmesi yeniden etkinleşince sunucudaki güncel veriyi gösterir',
    (tester) async {
      final api = _FakeApiService();
      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ada Green'), findsOneWidget);
      api.name = 'Güncel';
      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(apiService: api, refreshVersion: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Güncel Green'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'profile showcase opens grouped settings and logout resets navigation',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final apiService = _FakeApiService();
      final themeController = ThemeController();
      await tester.pumpWidget(
        ThemeScope(
          controller: themeController,
          child: MaterialApp(home: ProfileScreen(apiService: apiService)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ada Green'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('Eko Puan'), findsOneWidget);
      expect(find.text('Tarama Geçmişi'), findsOneWidget);

      await tester.tap(find.byTooltip('Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Profili Düzenle'), findsOneWidget);
      expect(find.text('Parolayı Değiştir'), findsOneWidget);
      expect(find.text('Dil'), findsOneWidget);

      final themeSelection = find.text('Tema Seçimi');
      await tester.ensureVisible(themeSelection);
      await tester.tap(themeSelection);
      await tester.pumpAndSettle();
      expect(find.text('Tema Seçimi'), findsWidgets);
      await tester.tap(find.text('Okyanus').last);
      await tester.pumpAndSettle();
      expect(find.text('Okyanus'), findsOneWidget);

      final logout = find.text('Çıkış Yap');
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();

      expect(apiService.didLogout, isTrue);
      expect(find.text("EcoVision'a Hoş Geldin"), findsOneWidget);
    },
  );

  testWidgets(
    'giriş serisi yalnız profil başlığında ve takvim dokununca açılır',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _FakeApiService();
      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giriş serisi'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ProfileIdentityHeader),
          matching: find.text('3 gün giriş serisi'),
        ),
        findsOneWidget,
      );
      expect(find.text('Giriş günlerin'), findsNothing);
      expect(api.historyMonths, isEmpty);
      final summary = find.byKey(const ValueKey('profile-login-streak'));
      await tester.ensureVisible(summary);
      await tester.tap(summary);
      await tester.pumpAndSettle();
      expect(find.text('Giriş günlerin'), findsOneWidget);
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(api.historyMonths, ['2026-10']);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('login-day-2026-10-24')))
            .label,
        contains('giriş yapıldı, bugün'),
      );
      semantics.dispose();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Sonraki ay',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Önceki ay'));
      await tester.pumpAndSettle();
      expect(find.text('Eylül 2026'), findsOneWidget);
      expect(api.historyMonths.last, '2026-09');
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş günlerin'), findsNothing);
      expect(find.text('3 gün giriş serisi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('takvim hata halinde tekrar denenebilir', (tester) async {
    final api = _FakeApiService()..failHistory = true;
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(apiService: api)));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profile-login-streak'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Giriş günlerin yüklenemedi.'), findsOneWidget);
    api.failHistory = false;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('başlıktan avatar değişimi profile hemen yansır', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(apiService: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Avatarı Düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seviye 2'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avatarı Seç'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    final avatar = tester.widget<PrivacyAwareAvatar>(
      find.byType(PrivacyAwareAvatar),
    );
    expect(
      avatar.selectedAvatarPath,
      'assets/images/avatars/avatar_level_2.png',
    );
    expect(avatar.avatarLevel, 2);
    expect(find.text('3 gün giriş serisi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eski sunucuda yalnız bilinen yedi gün gösterilir', (
    tester,
  ) async {
    final api = _FakeApiService()
      ..failHistory = true
      ..historyErrorStatus = 404;
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(apiService: api)));
    await tester.pumpAndSettle();
    final control = find.byKey(const ValueKey('profile-login-streak'));
    await tester.ensureVisible(control);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      find.text('Bu görünüm yalnızca son yedi günün kayıtlarını içerir.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Önceki ay',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final theme in AppThemeKind.values) {
    for (final width in [320.0, 430.0]) {
      testWidgets('$theme: uzun isim ve büyük yazı $width genişlikte taşmaz', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _FakeApiService()
          ..name = 'Çok Uzun İsimli Bir EcoVision'
          ..surname = 'Kahramanı Sürdürülebilirlik Gönüllüsü';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.forKind(theme),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: ProfileScreen(apiService: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileIdentityHeader), findsOneWidget);
        expect(tester.takeException(), isNull);
        final summary = find.byKey(const ValueKey('profile-login-streak'));
        await tester.ensureVisible(summary);
        await tester.tap(summary);
        await tester.pumpAndSettle();
        expect(find.text('Giriş günlerin'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _FakeApiService extends ApiService {
  Map<String, dynamic> impact = {};
  bool failImpact = false;
  String name = 'Ada';
  String surname = 'Green';
  int avatarLevel = 1;
  bool failHistory = false;
  int historyErrorStatus = 500;
  final List<String?> historyMonths = [];
  bool didLogout = false;
  final ValueNotifier<int> _points = ValueNotifier<int>(80);

  @override
  ValueListenable<int> get pointsListenable => _points;

  @override
  Future<UserProfile> fetchCurrentUser() async {
    return UserProfile(
      id: 1,
      name: name,
      surname: surname,
      username: 'ada.eco',
      email: 'ada@ecovision.test',
      totalPoints: 80,
      role: 'USER',
      city: 'Şanlıurfa',
      district: 'Haliliye',
      equippedAvatarLevel: avatarLevel,
      currentAvatarLevel: 2,
      selectedAvatarPath: 'assets/images/avatars/avatar_level_$avatarLevel.png',
      ownedMarketItems: {},
    );
  }

  @override
  Future<Map<String, dynamic>> fetchLoginStreak() async => {
    'today': '2026-10-24',
    'currentStreak': 3,
    'longestStreak': 9,
    'lastSevenDays': ['2026-10-22', '2026-10-23', '2026-10-24'],
  };

  @override
  Future<Map<String, dynamic>> fetchCarbonSummary() async {
    if (failImpact) throw ApiException('Bağlantı hatası', statusCode: 503);
    return impact;
  }

  @override
  Future<LoginActivityMonth> fetchLoginHistory({String? month}) async {
    historyMonths.add(month);
    if (failHistory) {
      throw ApiException('Test sunucu hatası', statusCode: historyErrorStatus);
    }
    return LoginActivityMonth.fromJson({
      'month': month ?? '2026-10',
      'today': '2026-10-24',
      'loginDates': month == '2026-09'
          ? ['2026-09-03']
          : ['2026-10-22', '2026-10-23', '2026-10-24'],
    });
  }

  @override
  Future<UserProfile> equipAvatar(int level) async {
    avatarLevel = level;
    return fetchCurrentUser();
  }

  @override
  Future<List<ScanResult>> getRecentScans() async {
    return [
      ScanResult(
        material: 'Plastik Şişe',
        isRecyclable: true,
        decayYears: '450 yıl',
        recycledInto: 'Tekstil lifi',
        scannedAt: DateTime(2026, 7, 22, 14, 30),
      ),
    ];
  }

  @override
  Future<GamificationState> fetchGamificationState() async {
    return const GamificationState(
      totalPoints: 80,
      carbonFootprintCompleted: false,
      redeemedRewardKeys: {},
      pointsAwarded: 0,
      message: 'Yüklendi',
    );
  }

  @override
  Future<List<LeaderboardEntry>> fetchCityLeaderboard() async {
    return const [
      LeaderboardEntry(
        rank: 1,
        userId: 1,
        fullName: 'Ada Green',
        city: 'Şanlıurfa',
        totalPoints: 80,
        currentUser: true,
      ),
    ];
  }

  @override
  Future<PublicProfile> fetchPublicProfile(int userId) async {
    return const PublicProfile(
      id: 1,
      fullName: 'Ada Green',
      city: 'Şanlıurfa',
      avatarLevel: 1,
      totalPoints: 80,
      streakCount: 3,
      likeCount: 2,
      liked: false,
      blocked: false,
      badges: [],
    );
  }

  @override
  Future<void> loadStoredSession() async {}

  @override
  Future<void> logout() async {
    didLogout = true;
  }
}
