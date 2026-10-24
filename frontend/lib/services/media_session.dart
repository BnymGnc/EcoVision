import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// Auth is supplied by the existing ApiService, never embedded in media URLs.
abstract final class MediaSession {
  static final revision = ValueNotifier<int>(0);
  static Future<Uint8List> Function(Uri)? _loader;
  static int? _account;
  static void bind(Future<Uint8List> Function(Uri) loader, int account) {
    _loader = loader;
    if (_account != account) {
      _account = account;
      revision.value++;
    }
  }

  static void clear() {
    _loader = null;
    _account = null;
    revision.value++;
  }

  static Future<Uint8List> load(Uri uri) async {
    final loader = _loader;
    final account = _account;
    final generation = revision.value;
    if (loader == null) throw StateError('Medya için giriş yapmalısın');
    final bytes = await loader(uri);
    if (_loader == null || _account != account || generation != revision.value)
      throw StateError('Oturum değişti');
    return bytes;
  }
}
