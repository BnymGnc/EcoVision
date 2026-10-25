import 'dart:convert';
import 'package:ecovision/core/turkey_locations.dart';
import 'package:ecovision/models/doa_catalog.dart';
import 'package:ecovision/models/map_pin.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/widgets/doa_area_picker.dart';
import 'package:flutter/material.dart';
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
  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );
  test(
    'numeric and textual coordinates reject NaN, infinity and out-of-range',
    () {
      for (final value in [double.nan, double.infinity, -91, 'NaN', '91']) {
        expect(
          () => MapPin.fromJson({'id': 1, 'latitude': value, 'longitude': 35}),
          throwsFormatException,
        );
      }
      final pin = MapPin.fromJson({
        'id': 1,
        'latitude': '38.7',
        'longitude': 35,
      });
      expect(pin.latitude, 38.7);
      expect(pin.longitude, 35.0);
    },
  );

  test(
    'search forwards city, district, viewport and page without downloading the entire catalog',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return http.Response(
              jsonEncode({
                'accessToken': 'test',
                'refreshToken': 'test',
                'user': {
                  'id': 1,
                  'name': 'Test',
                  'surname': 'Test',
                  'email': 'test@ecovision.invalid',
                  'age': 24,
                  'totalPoints': 0,
                },
              }),
              200,
            );
          }
          expect(request.url.path, '/api/map-pins/search');
          final query = request.url.queryParameters;
          expect(query['city'], 'Şanlıurfa');
          expect(query['district'], 'Haliliye');
          expect(query['offset'], '100');
          expect(query['limit'], '100');
          expect(query['south'], '37.0');
          expect(query.containsKey('radiusKm'), isFalse);
          return http.Response(
            jsonEncode({'items': [], 'total': 130, 'hasMore': true}),
            200,
          );
        }),
      );
      await api.login(email: 'test@ecovision.invalid', password: 'test');
      final page = await api.searchDoaPoints(
        latitude: 37.17,
        longitude: 38.8,
        city: 'Şanlıurfa',
        district: 'Haliliye',
        offset: 100,
        south: 37,
        north: 38,
        west: 38,
        east: 39,
      );
      expect(page.total, 130);
      expect(page.hasMore, isTrue);
    },
  );

  testWidgets(
    'all 81 city selections expose only their districts and reset the old district',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final areas = TurkishLocations.provinces.entries
          .map(
            (entry) => DoaArea(
              entry.key,
              const {'DIM': 0},
              null,
              entry.value
                  .map(
                    (district) => DoaArea(district, const {'DIM': 0}, null, []),
                  )
                  .toList(),
            ),
          )
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DoaAreaPicker(cities: areas)),
        ),
      );
      for (final area in areas) {
        final cityField = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('doa-city')),
        );
        final cityDropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: find.byKey(const ValueKey('doa-city')),
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(cityDropdown.items!.length, 81);
        cityField.onChanged!(area.name);
        await tester.pump();
        final districtFinder = find.byKey(
          ValueKey('doa-district-${area.name}'),
        );
        final field = tester.widget<DropdownButtonFormField<String>>(
          districtFinder,
        );
        final dropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: districtFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(field.initialValue, isNull);
        expect(
          dropdown.items!.map((item) => item.value).toList(),
          TurkishLocations.districtsFor(area.name),
        );
        field.onChanged!(area.districts.first.name);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
