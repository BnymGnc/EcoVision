import 'package:ecovision/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tema tercihleri kullanıcı hesapları arasında ayrı tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    await controller.bindToUser(101);
    await controller.select(AppThemeKind.ocean);

    await controller.bindToUser(202);
    expect(controller.selected, AppThemeKind.forest);
    await controller.select(AppThemeKind.sunset);

    await controller.bindToUser(101);
    expect(controller.selected, AppThemeKind.ocean);

    await controller.bindToUser(202);
    expect(controller.selected, AppThemeKind.sunset);
  });

  test('dört tema okunaklı yüzey renkleri sunar', () {
    for (final kind in AppThemeKind.values) {
      final scheme = AppThemes.forKind(kind).colorScheme;
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
    }
  });
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance() + 0.05;
  final dark = background.computeLuminance() + 0.05;
  return light > dark ? light / dark : dark / light;
}
