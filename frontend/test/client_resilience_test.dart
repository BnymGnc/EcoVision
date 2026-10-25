import 'dart:async';
import 'dart:convert';
import 'package:ecovision/main.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/services/chat_image_compressor.dart';
import 'package:ecovision/services/media_session.dart';
import 'package:ecovision/services/location_service.dart';
import 'package:ecovision/theme/theme_controller.dart';
import 'package:ecovision/widgets/authorized_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  var deletions = 0;
  setUp(() {
    deletions = 0;
    SharedPreferences.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'delete') deletions++;
      if (call.method == 'read') return 'saved-token';
      return null;
    });
  });
  tearDown(() {
    MediaSession.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'geçici sunucu hatası kayıtlı tokenları silmez ve tekrar denenebilir',
    () async {
      var unavailable = true;
      final api = ApiService(
        client: MockClient(
          (req) async => unavailable
              ? http.Response(
                  jsonEncode({'message': 'Bağlantı geçici olarak kesildi'}),
                  503,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                )
              : http.Response(
                  jsonEncode({
                    'id': 1,
                    'name': 'Test',
                    'surname': 'User',
                    'email': 'test@ecovision.invalid',
                    'totalPoints': 0,
                    'role': 'USER',
                    'city': 'Kayseri',
                    'ownedMarketItems': [],
                  }),
                  200,
                ),
        ),
      );
      await expectLater(api.loadStoredSession(), throwsA(isA<ApiException>()));
      expect(api.isAuthenticated, isTrue);
      expect(deletions, 0);
      unavailable = false;
      await api.loadStoredSession();
      expect(api.currentUser?.id, 1);
    },
  );

  test('access reddi sırasında geçici refresh hatası oturumu silmez', () async {
    final api = ApiService(
      client: MockClient(
        (req) async => req.url.path.endsWith('/refresh')
            ? http.Response('{"message":"Geçici hata"}', 503)
            : http.Response('{"message":"Token süresi doldu"}', 401),
      ),
    );
    await expectLater(api.loadStoredSession(), throwsA(isA<ApiException>()));
    expect(api.isAuthenticated, isTrue);
    expect(deletions, 0);
  });

  testWidgets('yanıtsız giriş isteği belirlenen sürede güvenli hata döndürür', (
    tester,
  ) async {
    final api = ApiService(
      requestTimeout: const Duration(milliseconds: 30),
      client: MockClient((req) => Completer<http.Response>().future),
    );
    final error = expectLater(
      api.login(
        email: 'test@ecovision.invalid',
        password: 'not-sent-to-network',
      ),
      throwsA(isA<ApiException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await error;
    expect(api.isAuthenticated, isFalse);
  });

  testWidgets(
    'açılış hatası girişe atmak yerine oturumu koruyarak tekrar dener',
    (tester) async {
      final api = _StartupApi();
      await tester.pumpWidget(
        EcoVisionApp(apiService: api, themeController: ThemeController()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bağlantı kurulamadı'), findsOneWidget);
      expect(api.logouts, 0);
      await tester.tap(find.text('Yeniden Dene'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(api.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'aynı anda aynı medyayı isteyenler tek istek paylaşır, kalıcı cache yoktur',
    () async {
      var calls = 0;
      final reply = Completer<Uint8List>();
      MediaSession.bind((_) {
        calls++;
        return reply.future;
      }, 1);
      final uri = Uri.parse('https://ecovision.invalid/api/media/test');
      final first = MediaSession.load(uri);
      final second = MediaSession.load(uri);
      expect(calls, 1);
      reply.complete(Uint8List.fromList([1, 2]));
      await Future.wait([first, second]);
      await MediaSession.load(uri);
      expect(calls, 2);
    },
  );

  testWidgets(
    'oturum kapanırken görselin yeniden yüklenmesi setState hatası üretmez',
    (tester) async {
      final pending = Completer<Uint8List>();
      MediaSession.bind((_) => pending.future, 1);
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthorizedImage('https://ecovision.invalid/api/media/test'),
        ),
      );
      MediaSession.clear();
      await tester.pump();
      expect(tester.takeException(), isNull);
      pending.complete(Uint8List.fromList([1]));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'sohbet sıkıştırması oranı korur ve en büyük kenarı 1600 yapar',
    () async {
      final bytes = image.encodePng(image.Image(width: 2000, height: 100));
      final jpeg = await compressChatImage(bytes);
      final decoded = image.decodeJpg(jpeg)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 80);
      expect(jpeg.length, lessThanOrEqualTo(2 * 1024 * 1024));
    },
  );
  test('bozuk sohbet fotoğrafı güvenli biçimde reddedilir', () async {
    await expectLater(
      compressChatImage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test(
    'GPS yokken etkinlikte harita fallback adresi gerçek konum sayılmaz',
    () async {
      final previous = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _NoLocationPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previous);
      final service = LocationService();
      await expectLater(
        service.getCurrentEventLocation(),
        throwsA(isA<LocationLookupException>()),
      );
      expect(service.lastLookupUsedFallback, isTrue);
      final mapFallback = await service.getCurrentOrFallbackLocation();
      expect(mapFallback.latitude, isNonZero);
    },
  );
}

class _NoLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

class _StartupApi extends ApiService {
  int calls = 0, logouts = 0;
  @override
  Future<void> loadStoredSession() async {
    if (++calls == 1) throw const ApiException('Geçici hata', statusCode: 503);
  }

  @override
  Future<void> logout() async {
    logouts++;
  }
}
