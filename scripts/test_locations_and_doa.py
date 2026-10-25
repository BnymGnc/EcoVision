import unittest
import json
from pathlib import Path

from audit_locations_and_doa import CityResolver, audit


class CityAuditTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report, cls.points = audit()
        cls.resolver = CityResolver({'Şanlıurfa': ['Haliliye'], 'Kayseri': ['Talas'],
                                    'İstanbul': ['Kadıköy'], 'Sakarya': ['Akyazı']})

    def test_snapshot_inventory_is_complete_and_unique(self):
        self.assertEqual(4037, self.report['sourcePoints'])
        self.assertEqual(4037, len({p['id'] for p in self.points}))
        self.assertEqual(2162, self.report['byType']['DIM'])
        self.assertEqual(4037, sum(p['total'] for p in self.report['cityTotals'])
                         + len(self.report['unresolved']))

    def test_all_provinces_including_zeros_and_all_districts_are_present(self):
        self.assertEqual(81, len(self.report['cityTotals']))
        self.assertEqual(973, self.report['districts'])

    def test_different_point_types_are_not_counted_as_machines(self):
        self.assertEqual(1764, self.report['byType']['MIN'])
        self.assertEqual(111, self.report['byType']['SDM'])

    def test_normalization_and_final_city_override_street_name(self):
        self.assertEqual(('Kayseri', 'Talas', 'ADDRESS_CITY_DISTRICT'),
                         self.resolver.resolve('İstanbul Caddesi No:5 KAYSERİ/TALAS'))
        self.assertEqual('Şanlıurfa', self.resolver.resolve('SANLIURFA/HALILIYE')[0])

    def test_reverse_address_and_country_suffix(self):
        self.assertEqual('Sakarya', self.resolver.resolve('Akyazı/Sakarya, Türkiye')[0])

    def test_missing_city_is_not_guessed(self):
        self.assertIsNone(self.resolver.resolve('Sokak No:10')[0])

    def test_bad_district_does_not_invent_a_district(self):
        self.assertEqual(('Şanlıurfa', '', 'ADDRESS_CITY_UNKNOWN_DISTRICT'),
                         self.resolver.resolve('ŞANLIURFA/99999'))

    def test_all_provinces_and_districts_round_trip_in_both_address_orders(self):
        catalog = json.loads((Path(__file__).resolve().parents[1] / 'frontend/assets/data/turkey_locations.json').read_text(encoding='utf-8'))
        resolver = CityResolver(catalog['provinces'])
        for city, districts in catalog['provinces'].items():
            for district in districts:
                with self.subTest(city=city, district=district):
                    self.assertEqual((city, district), resolver.resolve(f'No:42 {city}/{district}')[:2])
                    self.assertEqual((city, district), resolver.resolve(f'{district}/{city}, Türkiye')[:2])

    def test_backend_and_frontend_share_the_verified_catalog(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(json.loads((root / 'frontend/assets/data/turkey_locations.json').read_text(encoding='utf-8')),
                         json.loads((root / 'backend/src/main/resources/data/turkey_locations.json').read_text(encoding='utf-8')))

    def test_quality_and_district_inventory_cover_all_provinces(self):
        self.assertEqual(81, len(self.report['qualityByCity']))
        self.assertEqual(973, len(self.report['districtTotals']))
        self.assertEqual(4037, self.report['unknownTelemetryCount'])

    def test_urfa_street_is_not_a_province_match(self):
        resolver = CityResolver({'Şanlıurfa': ['Haliliye'], 'Diyarbakır': ['Kayapınar']})
        self.assertEqual(('Diyarbakır', 'Kayapınar'), resolver.resolve('Urfa Yolu No:12 DİYARBAKIR/KAYAPINAR')[:2])


if __name__ == '__main__':
    unittest.main()
