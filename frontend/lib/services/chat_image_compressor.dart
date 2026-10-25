import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

// On Android/iOS compute uses a background isolate. Web uses the same bounded
// transformation on the browser thread; do not describe it as a Web Worker.
Future<Uint8List> compressChatImage(Uint8List bytes) =>
    compute(_encodeChatImage, bytes);

Uint8List _encodeChatImage(Uint8List bytes) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Fotoğraf okunamadı.');
  }
  if (decoded == null) throw const FormatException('Fotoğraf okunamadı.');
  if (decoded.width > 1600 || decoded.height > 1600) {
    decoded = image.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 1600 : null,
      height: decoded.height > decoded.width ? 1600 : null,
    );
  }
  var quality = 84;
  var result = image.encodeJpg(decoded, quality: quality);
  while (result.length > 2 * 1024 * 1024 && quality > 42) {
    quality -= 8;
    result = image.encodeJpg(decoded, quality: quality);
  }
  if (result.length > 2 * 1024 * 1024) {
    throw const FormatException(
      'Fotoğraf sıkıştırıldıktan sonra da 2 MB sınırını aşıyor.',
    );
  }
  return result;
}
