import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:ecovision/models/doa_catalog.dart';
import 'package:ecovision/models/doa_marker_index.dart';
import 'package:ecovision/models/map_pin.dart';
import 'package:ecovision/screens/map_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:ecovision/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

MapPin pin(int id, {double lat = 38.72}) => MapPin.fromJson({
  'id': id,
  'title': 'Makine $id',
  'latitude': lat,
  'longitude': 35.48,
});

void main() {
  testWidgets(
    'moving before GPS resolves reuses one location request and drops stale searches',
    (tester) async {
      final api = _MapApi();
      final location = _SlowLocation();
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            apiService: api,
            locationService: location,
            tileProvider: _Tiles(),
          ),
        ),
      );
      await tester.pump();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      for (var burst = 0; burst < 4; burst++) {
        map.options.onPositionChanged!(map.mapController!.camera, true);
        await tester.pump(const Duration(milliseconds: 550));
      }
      expect(location.calls, 1);
      expect(api.calls, isEmpty);
      location.result.complete(const LatLng(38.72, 35.48));
      await tester.pumpAndSettle();
      expect(api.calls.length, 1);
      expect(api.calls.single.$1, 10);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'zoom and polar inputs stay finite; memory and marker work remain bounded',
    () {
      final index = DoaMarkerIndex();
      final pins = [
        for (var i = 0; i < 4037; i++)
          pin(
            i,
            lat: i == 0
                ? 90
                : i == 1
                ? -90
                : 38.72,
          ),
      ];
      for (final zoom in [
        double.nan,
        double.infinity,
        -1000.0,
        3.0,
        18.0,
        1000.0,
      ]) {
        final groups = index.groups(pins, zoom);
        expect(groups.expand((g) => g).length, DoaMarkerIndex.maxPins);
        expect(groups.length, lessThanOrEqualTo(DoaMarkerIndex.maxPins));
      }
      final groups = index.groups(pins, 13.1);
      for (var i = 0; i < 1000; i++) {
        expect(identical(index.groups(pins, 13.9), groups), isTrue);
      }
      expect(identical(index.groups([...pins], 13.9), groups), isFalse);
    },
  );

  test('local clustering microbenchmark, not physical phone frame timing', () {
    final pins = [for (var i = 0; i < 300; i++) pin(i, lat: 38.7 + i * 0.0002)];
    final old = Stopwatch()..start();
    for (var n = 0; n < 500; n++) {
      final groups = <String, List<MapPin>>{};
      final cell = 55 / (256 * math.pow(2, 13));
      for (final p in pins) {
        final x = (p.longitude + 180) / 360;
        final sinLat = math.sin(p.latitude * math.pi / 180);
        final y = 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
        groups
            .putIfAbsent(
              '${(x / cell).floor()}:${(y / cell).floor()}',
              () => [],
            )
            .add(p);
      }
      expect(groups, isNotEmpty);
    }
    old.stop();
    final index = DoaMarkerIndex();
    index.groups(pins, 13);
    final cached = Stopwatch()..start();
    for (var n = 0; n < 500; n++) {
      index.groups(pins, 13);
    }
    cached.stop();
    // Keep performance informational: wall-clock assertions would be flaky on CI.
    debugPrint(
      'CLUSTER_500_UPDATES_300_POINTS old_us=${old.elapsedMicroseconds} cached_us=${cached.elapsedMicroseconds}',
    );
  });

  testWidgets(
    'map caps radius, zoom and loaded pins; gesture burst makes one request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _MapApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            apiService: api,
            requestedMaterial: 'pet',
            locationService: _Location(),
            tileProvider: _Tiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.single, (50.0, 0));
      var map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.maxZoom, 18);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('100 nokta daha yükle'));
        await tester.pumpAndSettle();
      }
      expect(api.calls, [(50.0, 0), (50.0, 100), (50.0, 200)]);
      expect(find.text('100 nokta daha yükle'), findsNothing);
      for (var i = 0; i < 40; i++) {
        map.mapController!.move(
          const LatLng(38.72, 35.48),
          i.isEven ? 1000 : 4,
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      expect(map.mapController!.camera.zoom, 4);
      map.mapController!.move(const LatLng(38.72, 35.48), 1000);
      await tester.pump();
      expect(map.mapController!.camera.zoom, 18);
      final before = api.calls.length;
      for (var i = 0; i < 200; i++) {
        map.options.onPositionChanged!(map.mapController!.camera, true);
      }
      await tester.pump(const Duration(milliseconds: 549));
      expect(api.calls.length, before);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(api.calls.length, before + 1);
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      expect(find.text('Sınırsız mesafe'), findsNothing);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 1);
      expect(slider.max, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Location extends LocationService {
  @override
  Future<LatLng> getCurrentOrFallbackLocation() async {
    lastLookupUsedFallback = false;
    return const LatLng(38.72, 35.48);
  }
}

class _SlowLocation extends LocationService {
  int calls = 0;
  final result = Completer<LatLng>();
  @override
  Future<LatLng> getCurrentOrFallbackLocation() {
    calls++;
    return result.future;
  }
}

class _Tiles extends TileProvider {
  final _image = MemoryImage(File('web/favicon.png').readAsBytesSync());
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}

class _MapApi extends ApiService {
  final calls = <(double?, int)>[];
  @override
  Future<DoaSearchPage> searchDoaPoints({
    required double latitude,
    required double longitude,
    double? radiusKm,
    String? city,
    String? district,
    int offset = 0,
    Set<String> materials = const {},
    Set<String> pointTypes = const {'DIM'},
    bool openOnly = false,
    double? south,
    double? north,
    double? west,
    double? east,
    Future<void>? abortTrigger,
  }) async {
    calls.add((radiusKm, offset));
    return DoaSearchPage(
      [for (var i = 0; i < 100; i++) pin(offset + i + 1)],
      500,
      true,
    );
  }
}
