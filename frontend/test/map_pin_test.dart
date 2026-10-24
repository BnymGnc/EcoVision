import 'package:ecovision/models/map_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malzeme desteğini snapshot hazne durumundan ayırır', () {
    final pin = MapPin.fromJson({
      'id': 1,
      'title': 'Kaynak noktası',
      'latitude': 37.17,
      'longitude': '38.8',
      'pointType': 'DIM',
      'acceptedMaterials': ['pet', 'aluminum'],
      'binStates': {'pet': false, 'aluminum': true},
      'scheduleStatus': 'UNKNOWN',
    });
    expect(pin.longitude, 38.8);
    expect(pin.supports('pet'), isTrue);
    expect(pin.accepts('pet'), isFalse);
    expect(pin.supports('metal'), isFalse);
    expect(pin.supports('plastic'), isFalse);
    expect(pin.scheduleLabel, 'Saat bilgisi yok');
    expect(pin.snapshotAt, isNull);
  });
}
