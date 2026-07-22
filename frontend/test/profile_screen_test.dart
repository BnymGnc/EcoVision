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

void main() {
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
}

class _FakeApiService extends ApiService {
  bool didLogout = false;
  final ValueNotifier<int> _points = ValueNotifier<int>(80);

  @override
  ValueListenable<int> get pointsListenable => _points;

  @override
  Future<UserProfile> fetchCurrentUser() async {
    return const UserProfile(
      id: 1,
      name: 'Ada',
      surname: 'Green',
      email: 'ada@ecovision.test',
      totalPoints: 80,
      role: 'USER',
      city: 'Şanlıurfa',
      ownedMarketItems: {},
    );
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
