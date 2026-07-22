import 'package:ecovision/models/scan_result.dart';
import 'package:ecovision/models/gamification_state.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/screens/profile_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile menu opens destinations and logout resets navigation', (
    tester,
  ) async {
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
    expect(find.text('80 Eco Points'), findsOneWidget);

    final routes = <String, String>{
      'Edit Profile': 'Profile editor is coming soon',
      'Change Password': 'Password controls are coming soon',
      'Görevlerim': 'Small actions, lasting impact',
      'Eco-Market': 'Your Eco Wallet',
      'Waste Encyclopedia': 'Know before you throw',
      'Liderlik Tablosu': 'City rankings are coming soon',
      'Tarama Geçmişi': '1 items identified',
      'Ayarlar': 'Make EcoVision yours',
    };

    for (final route in routes.entries) {
      final menuItem = find.text(route.key).last;
      await tester.ensureVisible(menuItem);
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      expect(find.text(route.value), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    final logout = find.text('Çıkış Yap');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(apiService.didLogout, isTrue);
    expect(find.text('Welcome to EcoVision'), findsOneWidget);
  });
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
    );
  }

  @override
  Future<List<ScanResult>> getRecentScans() async {
    return [
      ScanResult(
        material: 'Plastic Bottle',
        isRecyclable: true,
        decayYears: '450 years',
        recycledInto: 'Textile fiber',
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
      message: 'Loaded',
    );
  }

  @override
  Future<void> loadStoredSession() async {}

  @override
  Future<void> logout() async {
    didLogout = true;
  }
}
