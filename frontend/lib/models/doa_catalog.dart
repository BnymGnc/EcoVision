import 'map_pin.dart';

class DoaSearchPage {
  const DoaSearchPage(
    this.items,
    this.total,
    this.hasMore, {
    this.totalIsExact = true,
  });
  factory DoaSearchPage.fromJson(Map<String, dynamic> json) => DoaSearchPage(
    (json['items'] as List)
        .map((item) => MapPin.fromJson(item as Map<String, dynamic>))
        .toList(),
    (json['total'] as num).toInt(),
    json['hasMore'] == true,
  );
  final List<MapPin> items;
  final int total;
  final bool hasMore;
  final bool totalIsExact;
}

class DoaArea {
  const DoaArea(this.name, this.counts, this.bounds, this.districts);
  factory DoaArea.fromJson(Map<String, dynamic> json) => DoaArea(
    json['name'] as String,
    (json['counts'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
    (json['bounds'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    (json['districts'] as List? ?? [])
        .map((item) => DoaArea.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
  final String name;
  final Map<String, int> counts;
  final Map<String, double>? bounds;
  final List<DoaArea> districts;
  int get total => counts.values.fold(0, (sum, value) => sum + value);
}
