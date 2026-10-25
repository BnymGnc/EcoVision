"""Offline, reproducible city counts from the canonical DOA snapshot.

No database/network calls. A DIM is a machine; MIN/KIM/SDM are counted separately.
Unresolved addresses stay unresolved, never assigned from a guessed coordinate.
"""
import argparse
from collections import Counter
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'backend/src/main/resources/data/data/doa_points_raw.json'
LOCATIONS = ROOT / 'frontend/assets/data/turkey_locations.json'
TYPES = ('DIM', 'MIN', 'KIM', 'SDM', 'UNKNOWN')


def normalize(text):
    text = str(text or '').replace('ı', 'i').replace('İ', 'I')
    return ''.join(c for c in unicodedata.normalize('NFKD', text.lower())
                   if not unicodedata.combining(c))


class CityResolver:
    def __init__(self, provinces):
        self.provinces = provinces
        self.names = {normalize(city): city for city in provinces}
        self.names.update({'icel': 'Mersin', 'afyon': 'Afyonkarahisar'})
        self.pattern = re.compile(r'(?<![a-z])(' + '|'.join(
            re.escape(name) for name in sorted(self.names, key=len, reverse=True)) + r')(?![a-z])')

    def resolve(self, address):
        address = normalize(address)
        # The source normally ends with CITY/DISTRICT. Searching only the
        # address avoids a shop named after another city overriding its city.
        for match in reversed(list(self.pattern.finditer(address))):
            city = self.names[match.group()]
            suffix = re.sub(r'[, ]*turkiye\s*$', '', address[match.end():]).strip(' /,.-')
            if not suffix:
                prefix = address[:match.start()].rstrip()
                for district in self.provinces[city]:
                    if re.search(r'(?:^|[^a-z])' + re.escape(normalize(district)) + r'\s*/\s*$', prefix):
                        return city, district, 'ADDRESS_CITY_DISTRICT'
                return city, '', 'ADDRESS_CITY'
            for district in self.provinces[city]:
                value = normalize(district)
                if re.match(re.escape(value) + r'(?:$|[^a-z])', suffix):
                    return city, district, 'ADDRESS_CITY_DISTRICT'
            if suffix.startswith('/') or address[match.end():].startswith('/') or suffix.isdigit():
                return city, '', 'ADDRESS_CITY_UNKNOWN_DISTRICT'
        return None, None, 'UNRESOLVED'


def audit(source=SOURCE, locations=LOCATIONS):
    catalog = json.loads(locations.read_text(encoding='utf-8'))
    provinces = catalog['provinces']
    if len(provinces) != 81 or sum(map(len, provinces.values())) != 973:
        raise ValueError('Incomplete province/district catalog')
    rows = json.loads(source.read_text(encoding='utf-8'))
    resolver = CityResolver(provinces)
    counts = {city: Counter() for city in provinces}
    district_counts = {city: {district: Counter() for district in districts}
                       for city, districts in provinces.items()}
    quality = {city: Counter() for city in provinces}
    coordinates, suspicious, unknown_status = {}, [], []
    point_rows, unresolved, district_warnings, seen = [], [], [], set()
    for row in rows:
        identifier = row['id']
        if identifier in seen:
            raise ValueError('Duplicate source UUID')
        seen.add(identifier)
        lat, lng = row['latitude'], row['longitude']
        if (isinstance(lat, bool) or isinstance(lng, bool)
                or not isinstance(lat, (int, float)) or not isinstance(lng, (int, float))
                or not math.isfinite(lat) or not math.isfinite(lng)
                or not -90 <= lat <= 90 or not -180 <= lng <= 180):
            raise ValueError('Invalid numeric coordinates: ' + identifier)
        kind = str(row.get('depositPointType', {}).get('name', '')).upper()
        if kind not in TYPES:
            kind = 'UNKNOWN'
        city, district, reason = resolver.resolve(row.get('address'))
        coordinates.setdefault((lat, lng), []).append(identifier)
        if not (35.8 <= lat <= 42.2 and 25.5 <= lng <= 45):
            suspicious.append({'id': identifier, 'latitude': lat, 'longitude': lng,
                               'city': city, 'reason': 'OUTSIDE_APPROXIMATE_TURKEY_ENVELOPE'})
            if city:
                quality[city]['suspiciousCoordinates'] += 1
        # No timestamp in this snapshot authenticates the freshness of bin state.
        unknown_status.append(identifier)
        if city:
            counts[city][kind] += 1
            quality[city]['telemetryTimeUnknown'] += 1
            if district:
                district_counts[city][district][kind] += 1
            else:
                quality[city]['districtUnresolved'] += 1
            if reason == 'ADDRESS_CITY_UNKNOWN_DISTRICT':
                district_warnings.append({'id': identifier, 'city': city, 'address': row.get('address', '')})
        else:
            unresolved.append({'id': identifier, 'pointType': kind,
                               'address': row.get('address', '')})
        point_rows.append({'id': identifier, 'city': city or '', 'district': district or '',
                           'pointType': kind, 'resolution': reason,
                           'latitude': lat, 'longitude': lng})
    summary = [{'city': city, **{kind: counts[city][kind] for kind in TYPES},
                'total': sum(counts[city].values())} for city in provinces]
    totals = Counter(point['pointType'] for point in point_rows)
    coordinate_duplicates = [{'latitude': coordinate[0], 'longitude': coordinate[1], 'ids': ids}
                             for coordinate, ids in coordinates.items() if len(ids) > 1]
    duplicate_ids = {identifier for group in coordinate_duplicates for identifier in group['ids']}
    for point in point_rows:
        if point['city'] and point['id'] in duplicate_ids:
            quality[point['city']]['sharedCoordinates'] += 1
    district_inventory = [{'city': city, 'district': district,
                           **{kind: counter[kind] for kind in TYPES}, 'total': sum(counter.values())}
                          for city, districts in district_counts.items() for district, counter in districts.items()]
    return {
        'snapshot': json.loads((source.parent / 'manifest.json').read_text(encoding='utf-8'))['fetched_at_utc'],
        'source': str(source.relative_to(ROOT)).replace('\\', '/'),
        'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'sourcePoints': len(rows), 'byType': {kind: totals[kind] for kind in TYPES},
        'provinces': len(provinces), 'districts': sum(map(len, provinces.values())),
        'cityTotals': summary, 'unresolved': unresolved, 'districtWarnings': district_warnings,
        'classifiedPoints': len(rows) - len(unresolved),
        'citiesWithMachines': sum(item['DIM'] > 0 for item in summary),
        'districtTotals': district_inventory,
        'qualityByCity': [{'city': city, 'coordinateMissing': 0, 'duplicateSourceIds': 0,
                           **{key: quality[city][key] for key in
                              ['suspiciousCoordinates', 'sharedCoordinates', 'telemetryTimeUnknown', 'districtUnresolved']}}
                          for city in provinces],
        'sharedCoordinateGroups': coordinate_duplicates,
        'suspiciousCoordinates': suspicious,
        'unknownTelemetryCount': len(unknown_status),
        'locationsSource': {key: catalog[key] for key in ['version', 'source', 'sha256']},
        'note': 'Snapshot/address-based inventory, not live availability or nationwide completeness guarantee.',
    }, point_rows


def csv_text(rows, fields):
    output = io.StringIO(newline='')
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator='\n')
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def write_reports(report, points, directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'doa-city-counts.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (directory / 'doa-city-counts.csv').write_text(csv_text(report['cityTotals'], ['city', *TYPES, 'total']), encoding='utf-8-sig')
    (directory / 'doa-district-counts.csv').write_text(csv_text(report['districtTotals'], ['city', 'district', *TYPES, 'total']), encoding='utf-8-sig')
    (directory / 'doa-city-quality.csv').write_text(csv_text(report['qualityByCity'], list(report['qualityByCity'][0])), encoding='utf-8-sig')
    (directory / 'doa-point-city-index.csv').write_text(csv_text(points, ['id', 'city', 'district', 'pointType', 'resolution', 'latitude', 'longitude']), encoding='utf-8-sig')
    lines = ['# DOA noktaları: il bazında envanter', '',
             f"Kaynak snapshot: {report['snapshot']}. Toplam **{report['sourcePoints']}** nokta; "
             f"bunların **{report['byType']['DIM']}** adedi DIM (iade makinesi).", '',
             'MIN/KIM merkez ve SDM türleri makine toplamına eklenmez. Sayılar canlı kabul/çalışma garantisi değildir.',
             'Adreslerdeki il/ilçe alanı esas alınır; belirsiz kayıtlar koordinattan tahmin edilmez.', '',
             '| İl | DIM: Makine | MIN | KIM | SDM | Bilinmeyen tür | Tüm noktalar |',
             '|---|---:|---:|---:|---:|---:|---:|']
    lines.extend('| ' + ' | '.join(str(row[key]) for key in ['city', *TYPES, 'total']) + ' |' for row in report['cityTotals'])
    unknown = Counter(row['pointType'] for row in report['unresolved'])
    lines.append('| İl bilgisi eksik | ' + ' | '.join(str(unknown[kind]) for kind in TYPES)
                 + f" | {len(report['unresolved'])} |")
    lines.append('| **Toplam** | ' + ' | '.join(str(report['byType'][kind]) for kind in TYPES)
                 + f" | {report['sourcePoints']} |")
    lines.extend(['', f"Sınıflandırılamayan adres: **{len(report['unresolved'])}**. Ayrıntı doa-city-counts.json içindedir.", '',
                  'Tekrar üretim: `python scripts/audit_locations_and_doa.py`. Veritabanına bağlanılmaz veya veri yazılmaz.',
                  'Konum kataloğunun kaynağı ve ad normalizasyonları: `frontend/assets/data/turkey_locations.json`.'])
    (directory / 'doa-city-counts-tr.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'docs')
    args = parser.parse_args()
    report, points = audit()
    write_reports(report, points, args.output)
    print(json.dumps({key: report[key] for key in ['sourcePoints', 'byType', 'classifiedPoints', 'citiesWithMachines']}, ensure_ascii=False))
    print('Unresolved address count:', len(report['unresolved']))


if __name__ == '__main__':
    main()
