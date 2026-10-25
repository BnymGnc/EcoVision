import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'map_pin.dart';

/// Bounded marker work; camera pans reuse projected points and zoom groups.
class DoaMarkerIndex {
  static const maxPins = 300;
  static const minZoom = 3.0;
  static const maxZoom = 18.0;
  List<MapPin>? _source;
  List<(MapPin, double, double)> _projected = [];
  int? _zoom;
  List<List<MapPin>> _groups = const [];

  List<List<MapPin>> groups(List<MapPin> pins, double zoom) {
    if (!identical(_source, pins)) {
      _source = pins;
      _zoom = null;
      _projected = [
        for (final pin in pins.take(maxPins))
          if (pin.latitude.isFinite && pin.longitude.isFinite) _project(pin),
      ];
    }
    final level = (zoom.isFinite ? zoom : 13).clamp(minZoom, maxZoom).floor();
    if (_zoom == level) return _groups;
    _zoom = level;
    final cell = 55 / math.pow(2, level);
    final cells = <(int, int), List<MapPin>>{};
    for (final point in _projected) {
      cells
          .putIfAbsent((
            (point.$2 / cell).floor(),
            (point.$3 / cell).floor(),
          ), () => [])
          .add(point.$1);
    }
    return _groups = List.unmodifiable(
      cells.values.map((group) => List<MapPin>.unmodifiable(group)),
    );
  }

  (MapPin, double, double) _project(MapPin pin) {
    final point = const Epsg3857().latLngToOffset(pin.point, 0);
    return (pin, point.dx, point.dy);
  }
}
