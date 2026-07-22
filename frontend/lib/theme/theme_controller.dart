import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeKind { forest, ocean, sunset, darkEco }

extension AppThemeKindDetails on AppThemeKind {
  String get label => switch (this) {
    AppThemeKind.forest => 'Forest',
    AppThemeKind.ocean => 'Ocean',
    AppThemeKind.sunset => 'Sunset',
    AppThemeKind.darkEco => 'Dark Eco',
  };

  String get description => switch (this) {
    AppThemeKind.forest => 'Grounded greens',
    AppThemeKind.ocean => 'Clear coastal blues',
    AppThemeKind.sunset => 'Warm coral energy',
    AppThemeKind.darkEco => 'Neon after dark',
  };

  Color get swatch => switch (this) {
    AppThemeKind.forest => const Color(0xFF2E7D32),
    AppThemeKind.ocean => const Color(0xFF006D77),
    AppThemeKind.sunset => const Color(0xFFD95D39),
    AppThemeKind.darkEco => const Color(0xFF7DFF8A),
  };
}

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'ecovision.theme';

  AppThemeKind _selected = AppThemeKind.forest;

  AppThemeKind get selected => _selected;
  ThemeData get themeData => AppThemes.forKind(_selected);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    for (final theme in AppThemeKind.values) {
      if (theme.name == stored) {
        _selected = theme;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> select(AppThemeKind theme) async {
    if (_selected == theme) {
      return;
    }
    _selected = theme;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, theme.name);
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope was not found above this context.');
    return scope!.notifier!;
  }
}

class AppThemes {
  const AppThemes._();

  static ThemeData forKind(AppThemeKind kind) => switch (kind) {
    AppThemeKind.forest => _build(
      seed: const Color(0xFF2E7D32),
      primary: const Color(0xFF2E7D32),
      secondary: const Color(0xFF2A7180),
      tertiary: const Color(0xFFD29A27),
      scaffold: const Color(0xFFF6FAF2),
      brightness: Brightness.light,
    ),
    AppThemeKind.ocean => _build(
      seed: const Color(0xFF006D77),
      primary: const Color(0xFF006D77),
      secondary: const Color(0xFFE76F51),
      tertiary: const Color(0xFF4D9DE0),
      scaffold: const Color(0xFFF2F9FB),
      brightness: Brightness.light,
    ),
    AppThemeKind.sunset => _build(
      seed: const Color(0xFFD95D39),
      primary: const Color(0xFFC84C2F),
      secondary: const Color(0xFF277DA1),
      tertiary: const Color(0xFFF2A65A),
      scaffold: const Color(0xFFFFF7F3),
      brightness: Brightness.light,
    ),
    AppThemeKind.darkEco => _build(
      seed: const Color(0xFF7DFF8A),
      primary: const Color(0xFF7DFF8A),
      secondary: const Color(0xFF65DDE0),
      tertiary: const Color(0xFFFFC857),
      scaffold: const Color(0xFF0E130F),
      brightness: Brightness.dark,
    ),
  };

  static ThemeData _build({
    required Color seed,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color scaffold,
    required Brightness brightness,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: brightness == Brightness.dark
          ? const Color(0xFF171D18)
          : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withAlpha(110),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
