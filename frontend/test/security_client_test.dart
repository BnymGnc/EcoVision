import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ecovision/models/academy_module.dart';
import 'package:ecovision/models/map_pin.dart';
import 'package:ecovision/services/academy_repository.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/services/media_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    ),
  );
  tearDown(() {
    MediaSession.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  Map<String, dynamic> identity() => {
    'accessToken': 'test-access',
    'refreshToken': 'test-refresh',
    'user': {
      'id': 1,
      'name': 'Test',
      'surname': 'User',
      'email': 'test@ecovision.invalid',
      'age': 24,
      'totalPoints': 0,
    },
  };
  test(
    'medya JWT header ile alınır; üçüncü tarafa token gönderilmez; çıkışta loader silinir',
    () async {
      var mediaCalls = 0;
      var logoutHeader = false;
      final api = ApiService(
        client: MockClient((req) async {
          if (req.url.path == '/api/auth/login') {
            return http.Response(jsonEncode(identity()), 200);
          }
          if (req.url.path == '/api/auth/logout') {
            logoutHeader = req.headers['Authorization'] == 'Bearer test-access';
            return http.Response('', 204);
          }
          mediaCalls++;
          expect(req.headers['Authorization'], 'Bearer test-access');
          expect(req.url.query.contains('token'), isFalse);
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      await api.login(email: 'test@ecovision.invalid', password: 'test');
      final uri = Uri.parse(
        '${ApiService.productionBaseUrl}/api/media/00000000-0000-0000-0000-000000000001',
      );
      expect(await MediaSession.load(uri), [1, 2, 3]);
      await expectLater(
        api.fetchMediaBytes(Uri.parse('https://evil.invalid${uri.path}')),
        throwsA(isA<ApiException>()),
      );
      expect(mediaCalls, 1);
      await api.logout();
      expect(logoutHeader, isTrue);
      await expectLater(MediaSession.load(uri), throwsStateError);
    },
  );
  test('hesap değişince devam eden medya yanıtı gösterilmez', () async {
    final pending = Completer<Uint8List>();
    MediaSession.bind((_) => pending.future, 1);
    final result = MediaSession.load(
      Uri.parse('https://local.invalid/api/media/id'),
    );
    MediaSession.clear();
    MediaSession.bind((_) async => Uint8List(0), 2);
    final assertion = expectLater(result, throwsStateError);
    pending.complete(Uint8List.fromList([1]));
    await assertion;
  });
  test(
    'sınav cevapları ve sürüm sunucuya gider, puan istemciden gönderilmez',
    () async {
      final api = ApiService(
        client: MockClient((req) async {
          if (req.url.path == '/api/auth/login') {
            return http.Response(jsonEncode(identity()), 200);
          }
          final body = jsonDecode(req.body) as Map;
          expect(body['answers'], [1, 0, 2]);
          expect(body['quizVersion'], AcademyModule.quizVersion);
          expect(body.containsKey('points'), isFalse);
          return http.Response(
            jsonEncode({
              'categoryId': 'modul-1',
              'newlyCompleted': true,
              'pointsAwarded': 30,
              'totalPoints': 30,
            }),
            200,
          );
        }),
      );
      await api.login(email: 'test@ecovision.invalid', password: 'test');
      await api.completeEducationModule(
        'modul-1',
        answers: [1, 0, 2],
        quizVersion: AcademyModule.quizVersion,
      );
      expect(api.pointsListenable.value, 30);
    },
  );
  test(
    'istemci ve sunucu sınav kataloğu aynı sürümde aynı 30 soruyu içerir',
    () async {
      final modules = await const AcademyRepository().loadModules();
      final server = jsonDecode(
        await File(
          '../backend/src/main/resources/education/academy-quiz-v1.json',
        ).readAsString(),
      );
      expect(server['version'], AcademyModule.quizVersion);
      for (final module in modules) {
        final remote = (server['modules'] as List).firstWhere(
          (m) => m['categoryId'] == module.categoryId,
        );
        for (var i = 0; i < 3; i++) {
          expect(
            remote['questions'][i]['questionText'],
            module.questions[i].questionText,
          );
          expect(
            remote['questions'][i]['options'],
            module.questions[i].options,
          );
          expect(
            remote['questions'][i]['correctOptionIndex'],
            module.questions[i].correctOptionIndex,
          );
        }
      }
    },
  );
  test('DOA desteği ve true/false/unknown durumlar birbirinden ayrıdır', () {
    final pin = MapPin.fromJson({
      'id': 1,
      'latitude': 38,
      'longitude': 35,
      'acceptedMaterials': ['pet', 'glass', 'aluminum'],
      'binStates': {'pet': true, 'glass': false},
    });
    expect(pin.supports('glass'), isTrue);
    expect(pin.binStates['pet'], isTrue);
    expect(pin.binStates['glass'], isFalse);
    expect(pin.binStates['aluminum'], isNull);
  });

  test(
    'eşzamanlı medya 401 yanıtları yalnız bir token yenilemesi yapar',
    () async {
      var refreshes = 0;
      final api = ApiService(
        client: MockClient((req) async {
          if (req.url.path == '/api/auth/login') {
            return http.Response(jsonEncode(identity()), 200);
          }
          if (req.url.path == '/api/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return http.Response(
              jsonEncode({...identity(), 'accessToken': 'new-access'}),
              200,
            );
          }
          if (req.headers['Authorization'] == 'Bearer test-access') {
            return http.Response('{}', 401);
          }
          return http.Response.bytes([1], 200);
        }),
      );
      await api.login(email: 'test@ecovision.invalid', password: 'test');
      final uri = Uri.parse(
        '${ApiService.productionBaseUrl}/api/media/00000000-0000-0000-0000-000000000001',
      );
      await Future.wait([api.fetchMediaBytes(uri), api.fetchMediaBytes(uri)]);
      expect(refreshes, 1);
    },
  );
  for (final upload in [false, true]) {
    test(
      'çıkış sonrası gecikmiş ${upload ? "yükleme" : "profil"} yanıtı yok sayılır',
      () async {
        final started = Completer<void>();
        final reply = Completer<http.Response>();
        final api = ApiService(
          client: MockClient((req) async {
            if (req.url.path == '/api/auth/login') {
              return http.Response(jsonEncode(identity()), 200);
            }
            if (req.url.path == '/api/auth/logout') {
              return http.Response('', 204);
            }
            started.complete();
            return reply.future;
          }),
        );
        await api.login(email: 'test@ecovision.invalid', password: 'test');
        final request = upload
            ? api.uploadProfilePicture(
                bytes: Uint8List.fromList([1]),
                fileName: 'test.jpg',
              )
            : api.fetchCurrentUser();
        final error = expectLater(request, throwsA(isA<ApiException>()));
        await started.future;
        await api.logout();
        reply.complete(http.Response(jsonEncode(identity()['user']), 200));
        await error;
        expect(api.currentUser, isNull);
        expect(api.pointsListenable.value, 0);
        expect(api.isAuthenticated, isFalse);
      },
    );
  }
  test('gecikmiş refresh yanıtı çıkıştan sonra oturumu geri açmaz', () async {
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    final api = ApiService(
      client: MockClient((req) async {
        if (req.url.path == '/api/auth/login') {
          return http.Response(jsonEncode(identity()), 200);
        }
        if (req.url.path == '/api/auth/refresh') {
          started.complete();
          return reply.future;
        }
        if (req.url.path == '/api/auth/logout') return http.Response('', 204);
        return http.Response('{}', 401);
      }),
    );
    await api.login(email: 'test@ecovision.invalid', password: 'test');
    final media = api.fetchMediaBytes(
      Uri.parse(
        '${ApiService.productionBaseUrl}/api/media/00000000-0000-0000-0000-000000000001',
      ),
    );
    final error = expectLater(media, throwsA(isA<ApiException>()));
    await started.future;
    await api.logout();
    reply.complete(
      http.Response(
        jsonEncode({...identity(), 'accessToken': 'late-access'}),
        200,
      ),
    );
    await error;
    expect(api.isAuthenticated, isFalse);
  });
}
