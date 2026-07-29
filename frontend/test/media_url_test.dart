import 'package:ecovision/core/media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('göreli yükleme adresini üretim sunucusuna bağlar', () {
    expect(
      MediaUrl.resolve('/uploads/groups/photo.jpg'),
      'https://ecovision-backend-wdr0.onrender.com/uploads/groups/photo.jpg',
    );
  });

  test('eski localhost yükleme adresini üretim sunucusuna taşır', () {
    expect(
      MediaUrl.resolve('http://localhost:8080/uploads/group-chat/photo.jpg'),
      'https://ecovision-backend-wdr0.onrender.com/uploads/group-chat/photo.jpg',
    );
  });
}
