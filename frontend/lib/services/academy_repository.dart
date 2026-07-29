import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/academy_module.dart';

class AcademyRepository {
  const AcademyRepository();

  static const assetPath = 'assets/data/academy_guide.json';

  Future<List<AcademyModule>> loadModules() async {
    final source = await rootBundle.loadString(assetPath);
    if (source.trim().isEmpty) {
      throw const FormatException(
        'Akademi veri dosyası boş. academy_guide.json içeriğini kontrol edin.',
      );
    }
    final decoded = jsonDecode(source);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('Akademi verisi boş veya geçersiz.');
    }
    final modules = decoded
        .map(
          (item) =>
              AcademyModule.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    final ids = modules.map((module) => module.categoryId).toSet();
    if (ids.length != modules.length) {
      throw const FormatException(
        'Akademi categoryId değerleri benzersiz olmalıdır.',
      );
    }
    return List.unmodifiable(modules);
  }
}
