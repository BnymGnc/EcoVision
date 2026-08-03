import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const _syncedPrefix = 'ecovision.theme.synced';
  static const _bootstrapKey = 'ecovision.theme.bootstrap';

  AppThemeKind _selected = AppThemeKind.forest;
  int? _activeUserId;
  Future<void> Function(String preference)? _remoteSaver;

  AppThemeKind get selected => _selected;
  ThemeData get themeData => AppThemes.forKind(_selected);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _selected =
        _parse(preferences.getString(_bootstrapKey)) ?? AppThemeKind.forest;
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
    final syncedKey = '$_syncedPrefix.$userId';
    final localPreference = preferences.getString(storageKey);
    final lastSyncedPreference = preferences.getString(syncedKey);
    final localTheme = _parse(localPreference);
    final remoteTheme = _parse(remotePreference);
    final lastSyncedTheme = _parse(lastSyncedPreference);

    // A remote value that changed since the last successful sync came from
    // another device and wins. Otherwise an unsynced local choice is retried.
    final remoteChangedElsewhere =
        remoteTheme != null &&
        lastSyncedTheme != null &&
        remoteTheme != lastSyncedTheme;
    _selected = remoteChangedElsewhere
        ? remoteTheme
        : localTheme ?? remoteTheme ?? AppThemeKind.forest;
    await preferences.setString(storageKey, _selected.name);
    await preferences.setString(_bootstrapKey, _selected.name);
    notifyListeners();

    if (remoteChangedElsewhere) {
      await preferences.setString(syncedKey, remoteTheme.name);
    } else if (remoteTheme != null && remoteTheme == _selected) {
      await preferences.setString(syncedKey, remoteTheme.name);
    } else if (localTheme != null &&
        remoteTheme != localTheme &&
        remoteSaver != null) {
      try {
        await remoteSaver(localTheme.name);
        await preferences.setString(syncedKey, localTheme.name);
      } catch (_) {
        // Local persistence keeps the UI stable while an offline server sync
        // is retried on the next authenticated app start.
      }
    }
  }

  void unbindUser() {
    _activeUserId = null;
    _remoteSaver = null;
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
    await preferences.setString(_bootstrapKey, theme.name);
    try {
      await _remoteSaver?.call(theme.name);
      await preferences.setString('$_syncedPrefix.$userId', theme.name);
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
      seed: const Color(0xFF10B981),
      primary: const Color(0xFF10B981),
      secondary: const Color(0xFF14532D),
      tertiary: const Color(0xFFC89B67),
      scaffold: const Color(0xFFF8F9FA),
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

    final textTheme =
        GoogleFonts.nunitoTextTheme(ThemeData(brightness: brightness).textTheme)
            .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
            .copyWith(
              displaySmall: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
              headlineLarge: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
              headlineMedium: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
              headlineSmall: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
              titleLarge: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
              bodyLarge: GoogleFonts.nunito(
                height: 1.5,
                color: scheme.onSurface,
              ),
              bodyMedium: GoogleFonts.nunito(
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
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
          side: BorderSide(color: scheme.outlineVariant.withAlpha(90)),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
