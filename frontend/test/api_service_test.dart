import 'dart:convert';

import 'package:ecovision/core/constants.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (_) async => null,
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      null,
    );
  });

  test('üretim API adresi canlı Render servisini kullanır', () {
    const expected = 'https://ecovision-backend-wdr0.onrender.com';
    expect(ApiService.productionBaseUrl, expected);
    expect(AppConstants.apiBaseUrl, expected);
    expect(ApiService.productionBaseUrl.endsWith('/'), isFalse);
  });

  test(
    'HTML sunucu hatasını kullanıcı dostu API hatasına dönüştürür',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '<html><body>Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        ),
      );
      final service = ApiService(client: client);

      await expectLater(
        service.login(email: 'user@ecovision.test', password: 'Test123!'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Sunucuya şu an ulaşılamıyor, lütfen tekrar deneyin.',
          ),
        ),
      );
    },
  );

  test('akademi ilerlemesindeki metin listesini doğru ayrıştırır', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'user': {
              'id': 1,
              'name': 'Ada',
              'surname': 'Eco',
              'email': 'ada@ecovision.test',
              'age': 24,
              'adult': true,
              'totalPoints': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/education/progress') {
        expect(request.headers['Authorization'], 'Bearer access');
        return http.Response(
          jsonEncode(['modul-1', 'modul-3']),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final service = ApiService(client: client);
    await service.login(email: 'ada@ecovision.test', password: 'Test123!');

    expect(await service.fetchEducationProgress(), {'modul-1', 'modul-3'});
  });

  test('kullanıcı avatar yolu ve mevcut seviyesi doğru ayrıştırılır', () {
    final profile = UserProfile.fromJson({
      'id': 4,
      'name': 'Ada',
      'surname': 'Eco',
      'email': 'ada@ecovision.test',
      'totalPoints': 600,
      'role': 'USER',
      'city': 'Kayseri',
      'ownedMarketItems': <String>[],
      'selectedAvatarPath': 'assets/images/avatars/avatar_level_5.png',
      'equippedAvatarLevel': 5,
      'currentAvatarLevel': 5,
    });

    expect(profile.currentAvatarLevel, 5);
    expect(
      profile.selectedAvatarPath,
      'assets/images/avatars/avatar_level_5.png',
    );
  });
}
