import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeKind { forest, ocean, sunset, darkEco }

extension AppThemeKindDetails on AppThemeKind {
  String get label => switch (this) {
    AppThemeKind.forest => 'Orman',
    AppThemeKind.ocean => 'Okyanus',
    AppThemeKind.sunset => 'Gün Batımı',
    AppThemeKind.darkEco => 'Karanlık Eko',
  };

  String get description => switch (this) {
    AppThemeKind.forest => 'Doğadan gelen yeşil tonları',
    AppThemeKind.ocean => 'Ferah kıyı mavileri',
    AppThemeKind.sunset => 'Sıcak mercan tonları',
    AppThemeKind.darkEco => 'Karanlık zeminde canlı yeşil',
  };

  Color get swatch => switch (this) {
    AppThemeKind.forest => const Color(0xFF2E7D32),
    AppThemeKind.ocean => const Color(0xFF006D77),
    AppThemeKind.sunset => const Color(0xFFD95D39),
    AppThemeKind.darkEco => const Color(0xFF7DFF8A),
  };
}

class ThemeController extends ChangeNotifier {
  static const _storagePrefix = 'ecovision.theme';

  AppThemeKind _selected = AppThemeKind.forest;
  int? _activeUserId;
  Future<void> Function(String preference)? _remoteSaver;

  AppThemeKind get selected => _selected;
  ThemeData get themeData => AppThemes.forKind(_selected);

  Future<void> load() async {
    _selected = AppThemeKind.forest;
    notifyListeners();
  }

  Future<void> bindToUser({
    required int userId,
    String? remotePreference,
    Future<void> Function(String preference)? remoteSaver,
  }) async {
    _activeUserId = userId;
    _remoteSaver = remoteSaver;
    final preferences = await SharedPreferences.getInstance();
    final storageKey = '$_storagePrefix.$userId';
    final localPreference = preferences.getString(storageKey);
    final localTheme = _parse(localPreference);
    final remoteTheme = _parse(remotePreference);

    // The device value is the most recent choice made on this installation.
    // The server value restores the account after a fresh installation.
    _selected = localTheme ?? remoteTheme ?? AppThemeKind.forest;
    await preferences.setString('$_storagePrefix.$userId', _selected.name);
    notifyListeners();

    if (localTheme != null &&
        remoteTheme != localTheme &&
        remoteSaver != null) {
      try {
        await remoteSaver(localTheme.name);
      } catch (_) {
        // Local persistence keeps the UI stable while an offline server sync
        // is retried on the next authenticated app start.
      }
    }
  }

  void unbindUser() {
    _activeUserId = null;
    _remoteSaver = null;
    _selected = AppThemeKind.forest;
    notifyListeners();
  }

  Future<void> select(AppThemeKind theme) async {
    if (_selected == theme) {
      return;
    }
    _selected = theme;
    notifyListeners();
    final userId = _activeUserId;
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_storagePrefix.$userId', theme.name);
    try {
      await _remoteSaver?.call(theme.name);
    } catch (_) {
      // Never roll the visible theme back because a network sync failed.
    }
  }

  AppThemeKind? _parse(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final theme in AppThemeKind.values) {
      if (theme.name == normalized) return theme;
    }
    return null;
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
      onSurface: brightness == Brightness.dark
          ? const Color(0xFFF1F7F1)
          : const Color(0xFF172018),
      onSurfaceVariant: brightness == Brightness.dark
          ? const Color(0xFFC7D2C7)
          : const Color(0xFF465147),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF0A0F0B)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF141A15)
          : const Color(0xFFF7FAF6),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF29312A)
          : const Color(0xFFE8EEE7),
    );

    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
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
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
